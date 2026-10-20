pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string steampath: "/mnt/DATA/SteamLibrary/"
    readonly property string workshoppath: "steamapps/workshop/content/431960/"
    readonly property string workshopBase: steampath + workshoppath
    readonly property string assetsPath: "file:///mnt/DATA/SteamLibrary/steamapps/common/wallpaper_engine/assets"

    // ==================== 持久化 ====================
    // 当前壁纸与播放参数写进 ~/.config/quickshell/wallpaper.json。
    // 下面这些 property alias 直接指向 JsonAdapter 的字段，改 alias 就等于改文件，
    // 重启 qs 后仍是同一张壁纸。
    // 注意：Config 不能被 Services 反向依赖（Services 已 import qs.Config），
    // 这里不引用 Directories，按 XDG 规范就地回退。
    readonly property string configPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/quickshell/wallpaper.json"

    // 场景壁纸跑在 Wallpaper/Load.qml 起的独立 opengl 进程里；那个进程只读配置，
    // 不写回，避免两个进程互相触发保存
    readonly property bool sceneChild: Quickshell.env("QS_WALLPAPER_SCENE_CHILD") === "1"

    FileView {
        id: store
        path: root.configPath
        blockLoading: true
        // 主进程改 fps / 暂停 / 静音后，独立场景进程要能收到：
        // 两个进程看同一个 wallpaper.json。watchChanges 只发 fileChanged，
        // 必须显式 reload() 才会重新解析。
        watchChanges: true
        atomicWrites: true
        onFileChanged: reload()
        printErrors: false

        JsonAdapter {
            id: cfg
            property string wallpaperId: "1761310151"
            property int fps: 60
            property real speed: 1.0
            property real volume: 1.0
            property bool muted: true
            property bool paused: false
        }
    }

    property alias wallpaperId: cfg.wallpaperId
    property alias fps: cfg.fps
    property alias speed: cfg.speed
    property alias volume: cfg.volume
    property alias muted: cfg.muted
    property alias paused: cfg.paused

    // JsonAdapter 的字段变化不会自己落盘，需要显式 writeAdapter()。
    // 用 400ms 去抖，拖 sliders 的时候不会每帧写文件。
    // 场景子进程只读不写，避免两个进程互相触发保存。
    Timer {
        id: saveTimer
        interval: 400
        repeat: false
        onTriggered: root.persist()
    }

    function persist(): void {
        if (root.sceneChild)
            return;
        store.writeAdapter();
    }

    onWallpaperIdChanged: {
        // 切换壁纸要立刻落盘：Load.qml 会马上按新 id 起外部渲染进程，
        // 那个进程启动时读的就是这个文件，去抖会读到旧 id
        saveTimer.stop();
        root.persist();
    }
    onFpsChanged: saveTimer.restart()
    onSpeedChanged: saveTimer.restart()
    onVolumeChanged: saveTimer.restart()
    onMutedChanged: saveTimer.restart()
    onPausedChanged: saveTimer.restart()

    // 首次启动时文件还不存在：先落一份默认值，之后 JsonAdapter 的写入就有目标文件。
    Process {
        id: ensureConfig
        running: true
        command: [
            "sh", "-c",
            "mkdir -p \"$(dirname \"$2\")\" && [ -s \"$2\" ] || printf '%s' \"$1\" > \"$2\"",
            "sh",
            "{\"wallpaperId\":\"1761310151\",\"fps\":60,\"speed\":1.0,\"volume\":1.0,\"muted\":true,\"paused\":false}",
            root.configPath
        ]
    }

    // ==================== 当前壁纸 ====================
    readonly property string sceneSource: workshopBase + wallpaperId + "/scene.pkg"
    readonly property string wallpaperType: adapter.type.toLowerCase() // "scene" / "video" / "web"
    readonly property string fileName: (adapter.type.toLowerCase() === "scene") ? "scene.pkg" : adapter.file
    readonly property string source: Qt.resolvedUrl(workshopBase + wallpaperId + "/" + fileName)

    FileView {
        path: root.workshopBase + root.wallpaperId + "/project.json"
        blockLoading: true
        printErrors: false

        JsonAdapter {
            id: adapter
            property string type
            property string file
        }
    }
}
