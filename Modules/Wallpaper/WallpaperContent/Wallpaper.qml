import QtMultimedia
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import com.github.captsilver.wallpaperEngineKde
import qs.Config
import qs.Services

// 壁纸渲染入口。渲染后端分工（见 Wallpaper/Load.qml）：
//   scene -> 只能 OpenGL。主进程是 Vulkan 时，Load.qml 会另起一个
//            QSG_RHI_BACKEND=opengl 的 qs 进程跑这个文件。
//   video -> 主进程内渲染，Vulkan（Mpv / QtMultimedia）。
//   web   -> Quickshell 本体无法加载 QtWebEngine（argc 被硬编码为 0），
//            这里启动 Wallpaper/Web.qml 交给 qml6 的独立进程渲染。
Item {
    id: root

    readonly property bool isVulkan: String(Quickshell.env("QSG_RHI_BACKEND") || "").toLowerCase() === "vulkan"

    // ==================== 窗口层（scene / video） ====================
    Instantiator {
        // 只有满足条件的组合才创建窗口
        model: {
            const type = WallpaperPath.wallpaperType;

            // 场景只支持 OpenGL：主进程是 Vulkan 时交给外部的 opengl 进程
            if (type === "scene" && !root.isVulkan)
                return [1];

            if (type === "video")
                return [1];

            // web 由独立的 QtWebEngine 进程渲染，这里不留窗口
            return [];
        }

        delegate: PanelWindow {
            aboveWindows: false
            focusable: false
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "Nox:wallpaper"
            WlrLayershell.layer: WlrLayer.Background
            implicitHeight: height
            implicitWidth: width

            anchors {
                left: true
                bottom: true
                right: true
                top: true
            }

            // --- 后端 A: SceneViewer（仅 OpenGL） ---
            Component {
                id: sceneComponent

                SceneViewer {
                    id: sceneView

                    source: WallpaperPath.source
                    assets: WallpaperPath.assetsPath
                    speed: WallpaperPath.speed
                    muted: WallpaperPath.muted
                    fps: WallpaperPath.fps

                    Component.onCompleted: {
                        setAcceptMouse(false);
                        setAcceptHover(false);
                        if (WallpaperPath.paused)
                            sceneView.pause();
                    }

                    Connections {
                        target: WallpaperPath
                        function onPausedChanged() {
                            if (WallpaperPath.paused)
                                sceneView.pause();
                            else
                                sceneView.play();
                        }
                    }
                }
            }

            // --- 后端 B: mpv（Vulkan，硬件解码） ---
            Component {
                id: mpvComponent

                Mpv {
                    id: player

                    source: WallpaperPath.source
                    mute: WallpaperPath.muted
                    // 帧率上限：mpv 的 max-fps（0 表示不限制）
                    maxFps: WallpaperPath.fps

                    function applyOptions() {
                        player.setProperty("keepaspect", true);
                        player.setProperty("panscan", 1);
                        player.setProperty("speed", WallpaperPath.speed);
                        player.setProperty("volume", WallpaperPath.volume);
                    }

                    onSourceChanged: {
                        applyOptions();
                        player.command(["set", "hwdec=vulkan-copy"]);
                        if (source.toString() !== "")
                            play();
                    }

                    Component.onCompleted: {
                        applyOptions();
                        if (WallpaperPath.paused)
                            player.pause();
                    }

                    Connections {
                        target: WallpaperPath
                        function onPausedChanged() {
                            if (WallpaperPath.paused)
                                player.pause();
                            else
                                player.play();
                        }
                        function onSpeedChanged() {
                            player.setProperty("speed", WallpaperPath.speed);
                        }
                    }
                }
            }

            // --- 后端 C: QtMultimedia（Vulkan 下的回退） ---
            Component {
                id: mediaComponent

                Video {
                    id: videoItem

                    source: WallpaperPath.source
                    autoPlay: !WallpaperPath.paused
                    loops: MediaPlayer.Infinite
                    muted: WallpaperPath.muted
                    volume: WallpaperPath.volume
                    playbackRate: WallpaperPath.speed

                    Connections {
                        target: WallpaperPath
                        function onPausedChanged() {
                            if (WallpaperPath.paused)
                                videoItem.pause();
                            else
                                videoItem.play();
                        }
                    }
                }
            }

            Loader {
                id: mainLoader

                anchors.fill: parent
                asynchronous: true // 异步加载，防止界面卡死

                sourceComponent: {
                    const type = WallpaperPath.wallpaperType;

                    if (type === "scene" && !root.isVulkan)
                        return sceneComponent;

                    if (type === "video")
                        return root.isVulkan ? mediaComponent : mpvComponent;

                    return null;
                }

                onStatusChanged: {
                    if (status === Loader.Error)
                        console.error("加载壁纸组件失败:", sourceComponent);
                }
            }
        }
    }

    // ==================== Web 壁纸（独立进程） ====================
    // scene 专用子进程（Wallpaper/Load.qml 起的 opengl 进程）不负责 Web，
    // 否则切换瞬间读到旧配置时会在里面重复起一个 WebEngine
    readonly property bool sceneChild: Quickshell.env("QS_WALLPAPER_SCENE_CHILD") === "1"

    readonly property bool webActive: !root.sceneChild && WallpaperPath.wallpaperType === "web"
        && String(WallpaperPath.source) !== ""

    property string webUrl: ""
    property bool webMuted: false
    property bool webPaused: false

    function syncWeb() {
        if (!root.webActive) {
            webProc.running = false;
            return;
        }

        const url = String(WallpaperPath.source);
        if (webProc.running && root.webUrl === url
                && root.webMuted === WallpaperPath.muted
                && root.webPaused === WallpaperPath.paused)
            return;

        root.webUrl = url;
        root.webMuted = WallpaperPath.muted;
        root.webPaused = WallpaperPath.paused;
        webProc.running = false;
        webRestart.restart();
    }

    Timer {
        id: webRestart
        interval: 250
        repeat: false
        onTriggered: if (root.webActive)
            webProc.running = true
    }

    Connections {
        target: WallpaperPath
        function onWallpaperTypeChanged() { root.syncWeb(); }
        function onSourceChanged() { root.syncWeb(); }
        function onMutedChanged() { root.syncWeb(); }
        function onPausedChanged() { root.syncWeb(); }
    }

    Component.onCompleted: root.syncWeb()

    // 切换到 scene 时 wallLoader 会销毁本 Item；子进程不一定跟着退出，
    // 显式按 pid 杀掉，避免孤儿 qml6 继续占着背景层
    Component.onDestruction: {
        webRestart.stop();
        if (webProc.running && webProc.processId)
            Quickshell.execDetached(["kill", String(webProc.processId)]);
    }

    Process {
        id: webProc
        running: false

        // fps 只在进程启动时传入；WebEngine 没有帧率上限接口，改帧率不影响 Web。
        command: [
            "qml6",
            Directories.configDir + "/Wallpaper/Web.qml",
            "--",
            root.webUrl,
            String(WallpaperPath.fps),
            root.webMuted ? "true" : "false",
            root.webPaused ? "true" : "false"
        ]
    }
}
