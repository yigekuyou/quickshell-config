import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Config
import qs.Services
import qs.Widget
import org.kde.kirigami as Kirigami

// 顶栏通知入口。外观与 Clipboard / Network / Bluetooth 一致。
//
// 以前这里是 Process { command: ["qs","--path",".../Wallpaper/Notif.qml","ipc","call","notif","open"] }：
// 每点一次都会另起一个 qs 进程去开另一个进程里的通知中心，那个子进程还持有
// org.freedesktop.Notifications 这个名字，和主进程抢 D-Bus（应用发通知会时好时坏）。
// 现在通知中心就在本进程里，点按钮只是切一个布尔值。
Kirigami.ShadowedRectangle {
    id: root

    implicitWidth: layout.implicitWidth + Kirigami.Units.largeSpacing * 2
    implicitHeight: Sizes.barHeight

    readonly property bool popupOpen: WidgetState.notifOpen
    readonly property bool containsMouse: hoverHandler.hovered
    readonly property int notifCount: NotificationManager.count

    color: Qt.alpha(Kirigami.Theme.backgroundColor, root.containsMouse || root.popupOpen ? 0.75 : 0.5)
    radius: Sizes.cornerRadius
    shadow.color: Qt.rgba(0, 0, 0, 0.2)
    shadow.size: 10
    shadow.yOffset: 2
    border.width: 1
    border.color: Qt.alpha(root.popupOpen ? Kirigami.Theme.highlightColor : Kirigami.Theme.dividerColor, 0.3)

    // --- 通知中心面板 ---
    NotificationWidget {
        id: popup
        anchorItem: root
        visible: root.popupOpen
        onCloseRequested: WidgetState.notifOpen = false
    }

    HoverHandler {
        id: hoverHandler
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: WidgetState.notifOpen = !WidgetState.notifOpen
    }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing / 2

        Kirigami.Icon {
            implicitWidth: Kirigami.Units.gridUnit * 0.9
            implicitHeight: Kirigami.Units.gridUnit * 0.9
            source: {
                if (NotificationManager.dnd)
                    return "notifications-disabled-symbolic";
                return root.notifCount > 0 ? "notifications-active-symbolic" : "notifications-symbolic";
            }
            color: NotificationManager.dnd ? Kirigami.Theme.disabledTextColor
                : (root.popupOpen ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor)
        }

        // 未读条数；为 0 时整段隐藏，部件自动收窄
        Label {
            visible: root.notifCount > 0
            text: root.notifCount
            font: Kirigami.Theme.smallFont
            color: NotificationManager.dnd ? Kirigami.Theme.disabledTextColor : Kirigami.Theme.textColor
            opacity: 0.85
        }
    }
}
