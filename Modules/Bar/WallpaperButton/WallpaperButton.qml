import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Config
import qs.Services
import qs.Widget
import qs.Modules.Wallpaper
import org.kde.kirigami as Kirigami

// 顶栏壁纸入口（左侧）。点开壁纸面板：预览、切换壁纸、调播放参数。
// 外观与 Clipboard / Network / Notification 一致。
Kirigami.ShadowedRectangle {
    id: root

    implicitWidth: layout.implicitWidth + Kirigami.Units.largeSpacing * 2
    implicitHeight: Sizes.barHeight

    readonly property bool popupOpen: WidgetState.wallpaperOpen
    readonly property bool containsMouse: hoverHandler.hovered

    color: Qt.alpha(Kirigami.Theme.backgroundColor, root.containsMouse || root.popupOpen ? 0.75 : 0.5)
    radius: Sizes.cornerRadius
    shadow.color: Qt.rgba(0, 0, 0, 0.2)
    shadow.size: 10
    shadow.yOffset: 2
    border.width: 1
    border.color: Qt.alpha(root.popupOpen ? Kirigami.Theme.highlightColor : Kirigami.Theme.dividerColor, 0.3)

    WallpaperPanel {
        id: popup
        anchorItem: root
        visible: root.popupOpen
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

    HoverHandler {
        id: hoverHandler
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: WidgetState.wallpaperOpen = !WidgetState.wallpaperOpen
    }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing / 2

        Kirigami.Icon {
            implicitWidth: Kirigami.Units.gridUnit * 0.9
            implicitHeight: Kirigami.Units.gridUnit * 0.9
            source: "preferences-desktop-wallpaper"
            color: root.popupOpen ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
        }

        // 当前帧率；比裸图标多一点信息，又不会把按钮撑太宽
        Label {
            text: WallpaperPath.fps
            visible: text !== ""
            font: Kirigami.Theme.smallFont
            opacity: 0.8
            color: Kirigami.Theme.textColor
        }
    }
}
