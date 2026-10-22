pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// ============================================================================
// 设置提供者：settings/settings.json 的唯一读写入口。
//
// 目录约定（见 Services/Directories.qml）：
//   settings/settings.json   本 shell 的全部可调参数（本文件负责）
//   settings/cava.conf       cava 的配置文件（cava 自己读，由设置面板可改）
//
// 为什么只有这里能持有 FileView：
//   JsonAdapter 写回时会序列化整棵 adapter 树。如果第二个 FileView 也打开
//   settings.json，两边各自只认识自己声明的字段，互相写回就会把对方的段落抹掉。
//   所以 Config/*.qml 一律通过这里暴露的子对象读写，不再各自开文件。
//
// 用法：
//   Settings.bar.height              读
//   Settings.bar.height = 1.8        写（150ms 去抖后落盘）
//   Settings.options.wallpaper.fps   等价写法（整棵树的根）
//   Settings.set("idle.locktime", 300)   通用写入口（设置面板 / IPC 用）
//   Settings.get("idle.locktime")
// ============================================================================
Singleton {
    id: root

    readonly property string path: Directories.settingsFile
    readonly property alias options: adapter

    // 常用段落单独暴露，省得每次写 Settings.options.xxx
    readonly property alias bar: barCfg
    readonly property alias island: islandCfg
    readonly property alias idle: idleCfg
    readonly property alias wallpaper: wallpaperCfg

    // 文件是否已经成功读过。首次启动文件不存在时会先落一份默认值。
    property bool ready: false
    // 外部要批量改值时可以临时关掉落盘（比如从文件重新载入时）
    property bool blockWrites: false
    // 壁纸场景子进程（Wallpaper/Wall.qml）只读配置：它没有任何要持久化的改动，
    // 放它写只会在两个进程之间来回覆盖（旧 wallpaper.json 时代就有的约定）
    readonly property bool readOnlyProcess: Quickshell.env("QS_WALLPAPER_SCENE_CHILD") === "1"

    // 最后一次落盘时间：用来区分“自己写的”和“外部改的”。
    // watchChanges 也可能看到我们自己的写入，收到后立刻 reload 会
    // adapterUpdated → 再写一次，形成来回抖动。
    property double lastWriteMs: 0

    // ==================== 通用读写口 ====================
    function set(nestedKey: string, value: var): void {
        const keys = nestedKey.split(".");
        let obj = root.options;

        for (let i = 0; i < keys.length - 1; ++i) {
            if (!obj[keys[i]] || typeof obj[keys[i]] !== "object")
                obj[keys[i]] = {};
            obj = obj[keys[i]];
        }

        obj[keys[keys.length - 1]] = value;
    }

    function get(nestedKey: string): var {
        const keys = nestedKey.split(".");
        let obj = root.options;

        for (let i = 0; i < keys.length; ++i) {
            if (obj === null || obj === undefined)
                return undefined;
            obj = obj[keys[i]];
        }

        return obj;
    }

    function reload(): void {
        view.reload();
    }

    // IPC / 设置面板共用的字符串解析：true/false/数字/JSON，其它按字符串
    function parseValue(text: string): var {
        const trimmed = String(text).trim();
        if (trimmed === "true")
            return true;
        if (trimmed === "false")
            return false;
        if (trimmed !== "" && !isNaN(Number(trimmed)))
            return Number(trimmed);
        try {
            return JSON.parse(trimmed);
        } catch (e) {
            return text;
        }
    }

    // ==================== IPC ====================
    // qs ipc call config set bar.height 2.0
    // qs ipc call config set wallpaper.fps 30
    // qs ipc call config get bar
    // qs ipc call config reload
    IpcHandler {
        target: "config"

        function set(key: string, value: string): void {
            root.set(key, root.parseValue(value));
        }

        function get(key: string): string {
            const value = root.get(key);
            // JsonObject 是 QObject，直接 stringify 会带出 objectName 之类的元属性
            if (value && typeof value === "object") {
                const out = {};
                for (const name in value) {
                    if (typeof value[name] !== "function" && name !== "objectName")
                        out[name] = value[name];
                }
                return JSON.stringify(out);
            }
            return JSON.stringify(value);
        }

        function reload(): void {
            root.reload();
        }
    }

    function flush(): void {
        if (root.blockWrites || root.readOnlyProcess || !root.ready)
            return;

        root.lastWriteMs = Date.now();
        view.writeAdapter();
    }

    // 去抖：拖滑块时每帧都改属性，不能每帧写文件
    Timer {
        id: writeTimer
        interval: 150
        repeat: false
        onTriggered: root.flush()
    }

    Timer {
        id: reloadTimer
        interval: 150
        repeat: false
        onTriggered: view.reload()
    }

    FileView {
        id: view

        path: root.path
        // 首次读取同步完成，保证 Config/* 拿到的是文件里的值而不是默认值
        blockLoading: true
        atomicWrites: true
        watchChanges: true
        blockWrites: root.blockWrites
        printErrors: false

        onFileChanged: {
            // 自己刚写过（400ms 内）就忽略这次变更，避免自激
            if (Date.now() - root.lastWriteMs > 400)
                reloadTimer.restart();
        }

        onAdapterUpdated: writeTimer.restart()

        onLoaded: root.ready = true

        onLoadFailed: error => {
            root.ready = false;
            // 文件不存在＝第一次启动：直接按 adapter 里的默认值落一份
            if (error === FileViewError.FileNotFound) {
                root.ready = true;
                writeTimer.restart();
            }
        }

        // ====================================================================
        // 全部可调参数。字段即 JSON 结构，默认值即首次启动写入的值。
        // 新增字段：在这里加一行，Settings.qml 的 alias / 设置面板各加一处。
        // ====================================================================
        JsonAdapter {
            id: adapter

            // 顶栏几何：数值是 gridUnit 的倍数（见 Config/Sizes.qml）
            property JsonObject bar: JsonObject {
                id: barCfg
                // 统一设置：整栏高度 / 圆角 / 是否显示文字 / 图标圆环
                property real height: 1.4
                property real cornerRadius: 0.5
                property bool labels: true
                property bool ring: true
                // 圆环几何：直径 = 图标 × ringScale（超出栏高时按栏高收住），
                // ringWidth 线宽，ringTrackOpacity 底环（未走完那圈）的浓度
                property real ringScale: 1.3
                property real ringWidth: 1.6
                property real ringTrackOpacity: 0.16
                // 分区设置：左 / 中 / 右 各自的 图标大小、内边距、按钮间距
                // （扁平键，避免 JsonAdapter 嵌套对象在写回时互相覆盖）
                property real leftIconSize: 0.85
                property real leftPadding: 0.28
                property real leftSpacing: 0.12
                property real centerIconSize: 0.85
                property real centerPadding: 0.28
                property real centerSpacing: 0.12
                property real rightIconSize: 0.85
                property real rightPadding: 0.28
                property real rightSpacing: 0.12
            }

            // 灵动岛（顶栏中间那个浮动面板）的尺寸，单位 = gridUnit
            property JsonObject island: JsonObject {
                id: islandCfg
                // 灵动岛（顶栏中间那个浮动面板）的尺寸，单位 = gridUnit
                property real collapsedWidth: 12
                property real collapsedHeight: 2
                property real expandedWidth: 24
                property real expandedHeight: 12
                property real lyricsWidth: 28
                property real lyricsHeight: 2
                property real dashboardWidth: 45
                property real dashboardHeight: 24
                property real authWidth: 30
                property real authHeight: 15
                // 圆角：小尺寸状态用 radius，大面板用 radius * 1.5
                property real radius: 1.0
            }

            // 空闲行为（见 Config/Idle.qml，秒）
            property JsonObject idle: JsonObject {
                id: idleCfg
                property bool lock: false
                property bool backlight: false
                property bool dpms: true
                property bool sleep: false
                property real lockTimeout: 180
                property real backlightTimeout: 300
                property real dpmsTimeout: 120
                property real sleepTimeout: 300
            }

            // 当前壁纸与播放参数（见 Config/WallpaperPath.qml）
            property JsonObject wallpaper: JsonObject {
                id: wallpaperCfg
                property string wallpaperId: "3541689554"
                property int fps: 60
                property real speed: 1
                property real volume: 1
                property bool muted: true
                property bool paused: false

                // ---- 以下对齐 Plasma Wallpaper Engine 插件
                // (com.github.captsilver.wallpaperEngineKde) 的设置面。
                // 字段名与语义跟它的 cfg_* 一一对应，默认值也取它的默认。
                // 标注 wired 的才是当前渲染器真正消费的，其余保留以便将来接入。
                property int pauseMode: 0              // 0 焦点或最大化 / 1 焦点 / 2 最大化 / 3 全屏 / 4 任意 / 5 从不
                property bool pauseFilterByScreen: false
                property bool pauseOnBattery: true
                property int pauseBatPercent: 20
                property int screenSaverPolicy: 1      // 0 继续运行 / 1 暂停
                property bool pauseDebugLogging: false
                property int renderScale: 100          // 100 / 75 / 50 / 25
                property int msaaMode: 0               // 0 自动 / 1 关 / 2 2x / 4 4x
                property int displayMode: 1            // 0 保持宽高比 / 1 裁剪填充 / 2 拉伸填充
                property string backgroundColor: "#000000"
                // 壁纸底色是否跟随系统配色方案（KDE 主题基色）。
                // false = 用 backgroundColor；true = 忽略 backgroundColor，
                // 直接跟随 Kirigami 主题基色（随 KDE 配色方案 / 明暗切换）。
                // 渲染端（WallpaperContent/Wallpaper.qml）读这个开关做选择，
                // Colorscheme.qml 本身不读它 —— 配色服务只管派生，分支留给壁纸侧。
                property bool schemeBackground: false
                property int resumeTime: 500           // ms
                property bool randomizeWallpaper: false
                property int switchTimer: 60           // 分钟
                property bool noRandomWhilePaused: true
                property bool playlistNotify: false
                property bool systemAudioCapture: false
                property bool mouseInput: true
                property bool animatedPreview: true
                property bool verboseLogging: false
                property int videoBackend: 1           // 0 QtMultimedia / 1 mpv
                property bool mpvStats: false
                property bool mpvPowerSaving: false
                property int presentMode: 1
                property bool hdrOutput: false
                property int cacheQuotaMB: 2048
            }
        }
    }
}