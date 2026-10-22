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

    // 实例化自动暂停服务（窗口策略 / 锁屏）；它只写 WallpaperPath.autoPaused，
    // 渲染端读 WallpaperPath.suspended。放在渲染进程里创建，场景子进程也能生效。
    readonly property var autoPause: WallpaperPause

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
            // 后端没出画之前是空白表面；PanelWindow 默认白底，在深色桌面里
            // 就是“壁纸变成纯白”。底色跟壁纸设置走（设置 → 壁纸 → 壁纸底色），
            // 由 Colorscheme 统一仲裁，不在各窗口里各写一个 #000000。
            color: Colorscheme.wallpaper_background
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

                    // 参数全部对齐 WE 插件 backend/Scene.qml 传给 SceneViewer 的那一组
                    source: WallpaperPath.source
                    assets: WallpaperPath.assetsPath
                    speed: WallpaperPath.speed
                    muted: WallpaperPath.muted
                    fps: WallpaperPath.fps
                    presentMode: Settings.wallpaper.presentMode
                    msaaMode: Settings.wallpaper.msaaMode
                    renderScale: Settings.wallpaper.renderScale / 100.0   // 插件里也是 /100
                    hdrOutput: Settings.wallpaper.hdrOutput
                    systemAudioCapture: Settings.wallpaper.systemAudioCapture
                    // 显示模式：0 保持宽高比（信箱） / 1 裁剪填充 / 2 拉伸填充
                    fillMode: Settings.wallpaper.displayMode === 0
                        ? SceneViewer.ASPECTFIT
                        : (Settings.wallpaper.displayMode === 1 ? SceneViewer.ASPECTCROP : SceneViewer.STRETCH)

                    // 插件里 scene 是吃鼠标的（交互式场景），这里跟设置项走
                    Component.onCompleted: {
                        setAcceptMouse(Settings.wallpaper.mouseInput);
                        setAcceptHover(Settings.wallpaper.mouseInput);
                        if (WallpaperPath.suspended)
                            sceneView.pause();
                    }

                    Connections {
                        target: Settings.wallpaper
                        function onMouseInputChanged() {
                            sceneView.setAcceptMouse(Settings.wallpaper.mouseInput);
                            sceneView.setAcceptHover(Settings.wallpaper.mouseInput);
                        }
                    }

                    Connections {
                        target: WallpaperPath
                        function onSuspendedChanged() {
                            if (WallpaperPath.suspended)
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
                        // 显示模式对齐 WE 插件：0 保持宽高比 / 1 裁剪填充 / 2 拉伸填充
                        const mode = Settings.wallpaper.displayMode;
                        player.setProperty("keepaspect", mode !== 2);
                        player.setProperty("panscan", mode === 1 ? 1 : 0);
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
                        // 先 play() 让 mpv 载入第一帧，再 pause()。
                        // 直接在未载入时 pause() 会得到一个没有任何画面的表面（纯色）。
                        if (WallpaperPath.suspended) {
                            player.play();
                            player.pause();
                        }
                    }

                    Connections {
                        target: WallpaperPath
                        function onSuspendedChanged() {
                            if (WallpaperPath.suspended)
                                player.pause();
                            else
                                player.play();
                        }
                        function onSpeedChanged() {
                            player.setProperty("speed", WallpaperPath.speed);
                        }
                        function onVolumeChanged() {
                            player.setProperty("volume", WallpaperPath.volume);
                        }
                    }

                    // 显示模式在 Settings 里（对齐 WE 插件的 cfg_DisplayMode）
                    Connections {
                        target: Settings.wallpaper
                        function onDisplayModeChanged() {
                            player.applyOptions();
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
                    autoPlay: !WallpaperPath.suspended
                    loops: MediaPlayer.Infinite
                    muted: WallpaperPath.muted
                    volume: WallpaperPath.volume
                    playbackRate: WallpaperPath.speed

                    Connections {
                        target: WallpaperPath
                        function onSuspendedChanged() {
                            if (WallpaperPath.suspended)
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
    // Web 选项的快照：改了选项要重启子进程才会生效（跨进程只能靠启动参数）
    property string webProps: ""
    // Web 子进程的底色。只在进程启动时传一次：它决定的是“页面画出来之前的
    // 那一瞬间”是什么颜色，改颜色不值得重启一整个 WebEngine，所以它不进下面的
    // “需要重启”比较条件，下次重启自然带上新值。
    readonly property string webBackground: String(Colorscheme.wallpaper_background)

    // ---- 暂停 / 终止：为什么要动信号，以及怎么保证不出孤儿 ----
    // 试过的替代方案（都实测过，结论写在这里免得以后重复踩）：
    //   * WebEngineView.lifecycleState = Frozen：视图可见时是空操作，
    //     页面里的 setInterval / rAF 照常跑（实测每 500ms 仍在打印）。
    //     QtWebEngine 只在页面被隐藏时才真的冻结（那时 recommendedState
    //     会变成 Frozen），而隐藏会丢掉最后一帧、只剩窗口底色 —— 对
    //     "一有窗口聚焦就暂停"的配置来说等于大半时间在看纯色。
    //   * 把暂停状态写文件让子进程轮询：子进程只能靠 QML Timer 轮询，
    //     而 Timer 依赖渲染帧驱动，页面/idle 时可能不触发，反而制造新的
    //     "永远醒不过来"。
    // 所以暂停仍然用 SIGSTOP/SIGCONT —— 它保住最后一帧、CPU 直接归零。
    // 真正要修的是它的三个副作用，下面逐个堵掉：
    //   1. pid 复用：kill 前先确认 /proc/<pid>/cmdline 还是我们的 qml6。
    //   2. 漏杀孤儿：pid 自己记，不依赖 Process.running（它在子进程已退出
    //      但未回收的窗口期是 false）。
    //   3. 父进程猝死导致子进程永久停在 T：shell.qml 启动时清扫残留进程；
    //      Web.qml 自己也会在父进程消失后退出。
    property int webChildPid: 0

    // 发信号前校验身份：pid 会被复用（一小时能起近百个 WebEngine），
    // 无脑 kill 有可能打到别的进程甚至 qs 自己。
    function signalWebChild(sig) {
        const pid = root.webChildPid;
        if (pid <= 0)
            return;
        pauseProc.command = ["sh", "-c",
            // comm 是内核给的可执行名（qml6），比 grep cmdline 可靠：
            // sh -c 自己的 cmdline 里也含 "qml6"/"Wallpaper/Web.qml"，
            // 用 cmdline 匹配会把 shell 自己也算成目标。
            "test \"$(cat /proc/" + pid + "/comm 2>/dev/null)\" = qml6"
            + " && grep -qa Wallpaper/Web.qml /proc/" + pid + "/cmdline 2>/dev/null"
            + " && kill -" + sig + " " + pid];
        pauseProc.running = true;
    }

    function killWebChild() {
        startPauseApply.stop();
        const pid = root.webChildPid;
        root.webChildPid = 0;
        if (pid <= 0)
            return;
        killProc.command = ["sh", "-c",
            "test \"$(cat /proc/" + pid + "/comm 2>/dev/null)\" = qml6"
            + " && grep -qa Wallpaper/Web.qml /proc/" + pid + "/cmdline 2>/dev/null"
            + " && kill -KILL " + pid];
        killProc.running = true;
    }

    // 两个 Process：暂停和清理可能同时发生（改选项的同时切窗口），
    // 共用一个对象会互相覆盖 command。
    Process {
        id: pauseProc
        running: false
    }

    Process {
        id: killProc
        running: false
    }

    // 新进程的"出生即暂停"宽限：先让它渲染出首屏，再 SIGSTOP 保住这一帧
    Timer {
        id: startPauseApply
        interval: 1500
        repeat: false
        onTriggered: if (WallpaperPath.suspended)
            root.signalWebChild("STOP")
    }

    // 键序无关的序列化：webSaved / webDefaults 每次重建顺序可能不同，
    // 直接比 JSON.stringify 会把“内容没变”判成变了，于是 Web 壁纸被反复重启
    function canonicalProps(obj) {
        if (!obj || typeof obj !== "object")
            return "{}";
        const keys = Object.keys(obj).sort();
        const out = {};
        for (const k of keys)
            out[k] = obj[k];
        return JSON.stringify(out);
    }

    function syncWeb() {
        if (!root.webActive) {
            webProc.running = false;
            return;
        }

        const url = String(WallpaperPath.source);
        const props = root.canonicalProps(WallpaperPath.webProperties);
        const paused = WallpaperPath.suspended;

        if (webProc.running && root.webUrl === url
                && root.webMuted === WallpaperPath.muted
                && root.webProps === props) {
            // 只有暂停/恢复变了：发一个信号就够，不用重启子进程。
            // 切工作区、开关窗口会频繁触发，重启整个 WebEngine 代价太大。
            // （SIGSTOP 比 lifecycleState 更合适：它保住最后一帧、CPU 归零；
            //   详见上方“暂停 / 终止”那段注释。）
            if (paused !== root.webPaused) {
                root.webPaused = paused;
                root.signalWebChild(paused ? "STOP" : "CONT");
            }
            return;
        }

        // url / 选项 / 静音变了：跨进程只能靠启动参数，必须重启。
        // 清理旧进程不再依赖 webProc.running —— 它只在 Process 自己察觉
        // 退出之前是 true，恰好在这段窗口期销毁就会漏杀，留下孤儿
        // WebEngine 继续占着背景层。pid 是自己记的，杀之前再校验一次身份。
        root.killWebChild();
        root.webUrl = url;
        root.webMuted = WallpaperPath.muted;
        root.webPaused = paused;
        root.webProps = props;
        webProc.running = false;
        webRestart.restart();
    }

    // ---- 传给 Web.qml 的参数：走文件，不走 argv ----
    // 之前是把 url / 静音 / 暂停 / 属性 JSON / 底色当成 argv 逐个位置传过去
    // （qm6 Web.qml -- a b c d e f），问题有三个：
    //   1) 属性 JSON 是 128 个键的对象，塞进 argv 要防引号、防长度；
    //   2) Web.qml 得按 dash+N 数位置，改一个参数就要两边一起改；
    //   3) qml6 会把“最后一个参数”当第二个 QML 文件，必须靠 "--" 分隔。
    // 改成父进程先写一个 JSON 规格文件，子进程只拿这一个路径，读文件即可。
    readonly property string webSpecPath: {
        const dir = String(Quickshell.env("XDG_RUNTIME_DIR") || "");
        return (dir !== "" ? dir : "/tmp") + "/quickshell-webwall.json";
    }

    function webSpec() {
        return JSON.stringify({
            "url": root.webUrl,
            "muted": root.webMuted,
            "paused": root.webPaused,
            "background": root.webBackground,
            "properties": root.webProps.length > 0 ? root.webProps : "{}"
        });
    }

    // 先把规格写盘，写成功再起进程 —— 起早了子进程会读到上一张壁纸的配置。
    function startWebChild() {
        specWriter.command = [
            "sh", "-c", "printf '%s' \"$1\" > \"$2\"", "sh",
            root.webSpec(), root.webSpecPath
        ];
        specWriter.running = true;
    }

    Process {
        id: specWriter
        running: false
        // 注意：Process 没有 exitCode 属性，退出码只在 exited(code, status) 的参数里
        onExited: (exitCode, exitStatus) => {
            if (exitStatus !== 0 || exitCode !== 0) {
                console.warn("[web-wallpaper] 规格文件写入失败:", exitCode, exitStatus);
                return;
            }
            if (root.webActive)
                webProc.running = true;
        }
    }

    Timer {
        id: webRestart
        // 改一个选项就重启一次子进程太贵；等一下让连续改动合并成一次
        interval: 600
        repeat: false
        onTriggered: if (root.webActive)
            root.startWebChild()
    }

    Connections {
        target: WallpaperPath
        function onWallpaperTypeChanged() { root.syncWeb(); }
        function onSourceChanged() { root.syncWeb(); }
        function onMutedChanged() { root.syncWeb(); }
        function onSuspendedChanged() { root.syncWeb(); }
        function onWebPropertiesChanged() { root.syncWeb(); }
    }

    Component.onCompleted: root.syncWeb()

    // 切换到 scene 时 wallLoader 会销毁本 Item；子进程不一定跟着退出，
    // 显式按 pid 杀掉，避免孤儿 qml6 继续占着背景层
    Component.onDestruction: {
        webRestart.stop();
        root.killWebChild();
    }

    Process {
        id: webProc
        running: false

        // 记下真实 pid，供 signalWebChild() / killWebChild() 校验后使用
        onStarted: {
            root.webChildPid = webProc.processId;
            // 出生时就该暂停的话要停住（启动参数里的 paused 只设置
            // lifecycleState，而它在可见视图上是空操作，光靠它新实例会继续跑）。
            // 但要等它画出第一帧再停：SIGSTOP 保住的是"最后一帧"，一开始就停
            // 就只有窗口底色。1.5s 的宽限对 WE 页面够画出首屏。
            if (WallpaperPath.suspended)
                startPauseApply.restart();
        }

        // QML_XHR_ALLOW_FILE_READ 是 Qt 的开关：QML 的 XMLHttpRequest 读本地
        // 文件默认被禁用（实测报 "Using GET on a local file is disabled"），
        // Web.qml 靠它读参数文件（以及 /proc/self/stat）。
        // 参数只有一个：规格文件路径。其余全部在那个 JSON 里。
        command: [
            "/usr/bin/env",
            "QML_XHR_ALLOW_FILE_READ=1",
            "qml6",
            Directories.configDir + "/Wallpaper/Web.qml",
            "--",
            root.webSpecPath
        ]
    }
}
