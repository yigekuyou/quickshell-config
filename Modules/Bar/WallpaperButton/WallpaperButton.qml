import QtQuick
import Quickshell
import Quickshell.Io
import qs.Config
import qs.Services
import qs.Widget
import qs.Modules.Wallpaper
import qs.Modules.Bar.common
import org.kde.kirigami as Kirigami

// 顶栏壁纸入口（左侧）。点开壁纸面板：预览、切换壁纸、调播放参数。
// 外观与 Clipboard / Network / Notification 一致，统一来自 BarButton。
BarButton {
    id: root

    checked: WidgetState.wallpaperOpen
    icon: "preferences-desktop-wallpaper"
    iconSize: Kirigami.Units.gridUnit * 0.9
    // 当前帧率；比裸图标多一点信息，又不会把按钮撑太宽。空字符串时自动隐藏。
    text: WallpaperPath.fps

    onClicked: WidgetState.wallpaperOpen = !WidgetState.wallpaperOpen

    WallpaperPanel {
        id: popup
        anchorItem: root
        visible: WidgetState.wallpaperOpen
        onCloseRequested: WidgetState.wallpaperOpen = false
        // 面板被合成器/点击外部关掉时同步状态，否则下一次点击只是把
        // WidgetState.wallpaperOpen 改回 false，看起来像要点两次
        onClosed: WidgetState.wallpaperOpen = false
    }

    // IPC：qs ipc call wall toggle / open / close
    IpcHandler {
        target: "wall"

        function toggle(): void {
            WidgetState.wallpaperOpen = !WidgetState.wallpaperOpen;
        }

        function open(): void {
            WidgetState.wallpaperOpen = true;
        }

        function close(): void {
            WidgetState.wallpaperOpen = false;
        }
    }
}