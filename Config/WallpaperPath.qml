pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

// ============================================================================
// 当前壁纸与播放参数的对外 API。
//
// 持久化分两类：
//   1. 播放参数（fps / speed / volume / paused ...）→ Services/Settings
//      的 settings/settings.json（wallpaper 段）。
//   2. 每张 Web 壁纸自己的选项 → settings/wallpaper/<壁纸 id>.json。
//      选项定义（类型 / 文案 / 默认值）来自壁纸目录里的 project.json，
//      这里只保存用户改过的值，没改过的继续用 project.json 的默认值。
//      一张壁纸一份文件，换壁纸互不覆盖；这个目录写进 .gitignore。
//
// 这里只做三件事：
//   1. 提供只读的路径推导（steampath / workshopBase / source ...）
//   2. 暴露同名属性给全项目用（WallpaperPath.fps 等，用法与以前完全一致）
//   3. 双向同步：本地赋值 -> 写 Settings；Settings 变化（设置面板 / 手改 json）
//      -> 拉回本地属性
//
// 以前这里自己开 FileView 写 wallpaper.json；现在 settings.json 全局只有
// Settings 允许持有 FileView（JsonAdapter 写回会序列化整棵树，两个 FileView
// 会互相抹掉对方不认识的字段）。每张壁纸的选项文件是独立文件，不存在这个
// 问题，所以由本文件自己读写。
// ============================================================================
Item {
    id: root

    // ==================== Wallpaper Engine 路径 ====================
    readonly property string steampath: "/mnt/DATA/SteamLibrary/"
    readonly property string workshoppath: "steamapps/workshop/content/431960/"
    readonly property string workshopBase: steampath + workshoppath
    readonly property string assetsPath: "file:///mnt/DATA/SteamLibrary/steamapps/common/wallpaper_engine/assets"

    // ==================== 可写参数 ====================
    // 初值是到 settings.json 的绑定（文件读完前先是 Settings 里的默认值）；
    // 一旦有人赋值，绑定断开，由下面的 onXChanged / Connections 接管双向同步。
    property string wallpaperId: Settings.wallpaper.wallpaperId
    property int fps: Settings.wallpaper.fps
    property real speed: Settings.wallpaper.speed
    property real volume: Settings.wallpaper.volume
    property bool muted: Settings.wallpaper.muted
    property bool paused: Settings.wallpaper.paused

    // 自动暂停（窗口策略 / 锁屏）：由 Services/WallpaperPause 驱动，
    // 不写回 settings.json，也不顶掉用户手动点出来的 paused。
    // 渲染端一律读 suspended。
    property bool autoPaused: false
    readonly property bool suspended: root.paused || root.autoPaused

    // 本地 -> settings.json（Settings 内部 150ms 去抖后落盘）
    onWallpaperIdChanged: Settings.wallpaper.wallpaperId = root.wallpaperId
    onFpsChanged: Settings.wallpaper.fps = root.fps
    onSpeedChanged: Settings.wallpaper.speed = root.speed
    onVolumeChanged: Settings.wallpaper.volume = root.volume
    onMutedChanged: Settings.wallpaper.muted = root.muted
    onPausedChanged: Settings.wallpaper.paused = root.paused

    // settings.json -> 本地（设置面板改值、手改文件后 reload、场景子进程以外的写入）
    Connections {
        target: Settings.wallpaper

        function onWallpaperIdChanged(): void {
            if (root.wallpaperId !== Settings.wallpaper.wallpaperId)
                root.wallpaperId = Settings.wallpaper.wallpaperId;
        }
        function onFpsChanged(): void {
            if (root.fps !== Settings.wallpaper.fps)
                root.fps = Settings.wallpaper.fps;
        }
        function onSpeedChanged(): void {
            if (root.speed !== Settings.wallpaper.speed)
                root.speed = Settings.wallpaper.speed;
        }
        function onVolumeChanged(): void {
            if (root.volume !== Settings.wallpaper.volume)
                root.volume = Settings.wallpaper.volume;
        }
        function onMutedChanged(): void {
            if (root.muted !== Settings.wallpaper.muted)
                root.muted = Settings.wallpaper.muted;
        }
        function onPausedChanged(): void {
            if (root.paused !== Settings.wallpaper.paused)
                root.paused = Settings.wallpaper.paused;
        }
    }

    // ==================== Web 壁纸选项 ====================
    // 选项定义来自 <壁纸>/project.json 的 general.properties，
    // 用户改过的值存 settings/wallpaper/<壁纸 id>.json。
    readonly property string webSettingsFile: root.wallpaperId.length > 0
        ? (Directories.wallpaperSettingsDir + "/" + root.wallpaperId + ".json")
        : ""

    // <壁纸 id>.json 里读到的覆盖值（只含用户改过的键）
    property var webSaved: ({})

    // 设置面板与渲染端都读这个：默认值打底，用户值覆盖。
    readonly property var webProperties: {
        const out = {};
        for (const k in root.webDefaults)
            out[k] = root.webDefaults[k];
        for (const k in root.webSaved)
            out[k] = root.webSaved[k];
        return out;
    }

    // 改一个选项：写进覆盖表并落盘（只写这一张壁纸的文件）
    function setWebProperty(key: string, value: var): void {
        const next = {};
        for (const k in root.webSaved)
            next[k] = root.webSaved[k];
        next[key] = value;
        root.webSaved = next;
    }

    // 整批替换覆盖表（恢复默认时用空对象）
    function setWebProperties(props: var): void {
        root.webSaved = props || {};
    }

    // 读盘/换壁纸时的回填不触发写盘（否则每看一张壁纸就多一个空 {} 文件）
    property bool suppressWebWrite: false
    // 覆盖文件是否已经读过一遍。singleton 刚创建时 webSaved 的初值
    // 也会发一次 changed，那时不能写盘，否则会给当前壁纸凭空建一个 {}
    property bool savedLoaded: false
    // 刚写过的那份文件：写完之后 FileView 还会再发一次 loaded，
    // 那次读到的可能是旧内容，用它把自己的回显挡掉
    property string lastWritePath: ""
    property double lastWriteMs: 0

    // 键序无关的序列化：同一份内容不管读回来是什么顺序，比较结果都一样。
    // 覆盖文件是“写 -> watchChanges -> 再读”的闭环，没有这一步会
    // 一直来回写，壁纸跟着重载。
    function canonical(obj: var): string {
        if (!obj || typeof obj !== "object")
            return "{}";
        const keys = Object.keys(obj).sort();
        const out = {};
        for (const k of keys)
            out[k] = obj[k];
        return JSON.stringify(out);
    }

    function applySaved(props: var): void {
        root.suppressWebWrite = true;
        root.webSaved = props || ({});
        root.suppressWebWrite = false;
    }

    // 覆盖表变化 -> 写 settings/wallpaper/<壁纸 id>.json
    onWebSavedChanged: {
        if (!root.savedLoaded || root.suppressWebWrite || !root.webSettingsFile.length)
            return;
        const text = JSON.stringify(root.webSaved, null, 2) + "\n";
        // 盘上已经是这份内容就别再写：写一次会触发一次 watchChanges 回读，
        // 回读再算一次 webSaved，就成环了（壁纸跟着反复重载）
        if (String(savedView.text() || "") === text)
            return;
        root.lastWritePath = root.webSettingsFile;
        root.lastWriteMs = Date.now();
        savedView.setText(text);
    }

    // ==================== 当前壁纸推导 ====================
    readonly property string sceneSource: workshopBase + wallpaperId + "/scene.pkg"
    readonly property string wallpaperType: root.projectType.toLowerCase() // "scene" / "video" / "web"
    readonly property string fileName: (root.wallpaperType === "scene") ? "scene.pkg" : root.projectFile
    readonly property string source: Qt.resolvedUrl(workshopBase + wallpaperId + "/" + fileName)

    // 创意工坊目录里的 project.json：只读，拿类型、入口文件名和 Web 选项定义。
    // 用 text() + JSON.parse 而不是 JsonAdapter：general.properties 的键是
    // 任意名字（每张壁纸不同），JsonAdapter 需要预先声明字段，接不住。
    property var project: ({})

    readonly property string projectType: root.project && root.project.type ? String(root.project.type) : ""
    readonly property string projectFile: root.project && root.project.file ? String(root.project.file) : ""

    // project.json 里的 Web 选项默认值（键 -> value）
    readonly property var webDefaults: {
        const out = {};
        const p = root.project && root.project.general ? root.project.general.properties : null;
        if (p) {
            for (const key in p) {
                const prop = p[key];
                out[key] = prop && prop.value !== undefined ? prop.value : "";
            }
        }
        return out;
    }

    FileView {
        id: projectView
        path: root.workshopBase + root.wallpaperId + "/project.json"
        blockLoading: true
        printErrors: false

        onLoaded: {
            let obj = {};
            try {
                const text = String(projectView.text() || "");
                const parsed = text.length > 0 ? JSON.parse(text) : ({});
                if (parsed && typeof parsed === "object")
                    obj = parsed;
            } catch (e) {
                obj = {};
            }
            root.project = obj;
        }

        onLoadFailed: root.project = ({})
    }

    // 每张壁纸自己的覆盖值
    FileView {
        id: savedView
        path: root.webSettingsFile
        blockLoading: true
        atomicWrites: true
        printErrors: false

        onLoaded: {
            // 自己刚写过：忽略这次回显，否则会把内存里的值打回旧内容
            if (savedView.path === root.lastWritePath && Date.now() - root.lastWriteMs < 800)
                return;
            let parsed = {};
            try {
                const text = String(savedView.text() || "");
                const obj = text.length > 0 ? JSON.parse(text) : ({});
                if (obj && typeof obj === "object")
                    parsed = obj;
            } catch (e) {
                // 文件坏了就当没设置过，下次改动会重写
                parsed = {};
            }
            if (root.canonical(parsed) !== root.canonical(root.webSaved))
                root.applySaved(parsed);
            root.savedLoaded = true;
        }

        onLoadFailed: error => {
            if (savedView.path === root.lastWritePath && Date.now() - root.lastWriteMs < 800)
                return;
            // 这张壁纸还没存过选项：全部走 project.json 的默认值
            root.applySaved({});
            root.savedLoaded = true;
        }
    }
}
