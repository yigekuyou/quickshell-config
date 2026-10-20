pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

// ============================================================================
// 当前壁纸与播放参数的对外 API。
//
// 持久化统一交给 Services/Settings（settings/settings.json 的 wallpaper 段），
// 这里只做三件事：
//   1. 提供只读的路径推导（steampath / workshopBase / source ...）
//   2. 暴露同名属性给全项目用（WallpaperPath.fps 等，用法与以前完全一致）
//   3. 双向同步：本地赋值 -> 写 Settings；Settings 变化（设置面板 / 手改 json）
//      -> 拉回本地属性
//
// 以前这里自己开 FileView 写 wallpaper.json；现在全局只有 Settings 允许持有
// settings.json 的 FileView（JsonAdapter 写回会序列化整棵树，两个 FileView
// 会互相抹掉对方不认识的字段）。
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

    // ==================== 当前壁纸推导 ====================
    readonly property string sceneSource: workshopBase + wallpaperId + "/scene.pkg"
    readonly property string wallpaperType: adapter.type.toLowerCase() // "scene" / "video" / "web"
    readonly property string fileName: (adapter.type.toLowerCase() === "scene") ? "scene.pkg" : adapter.file
    readonly property string source: Qt.resolvedUrl(workshopBase + wallpaperId + "/" + fileName)

    // 创意工坊目录里的 project.json：只读，拿类型和入口文件名
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