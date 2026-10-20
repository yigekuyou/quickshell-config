import QtQuick
import Quickshell
import qs.Config
import qs.Services
import qs.Widget
import qs.Modules.Bar.common
import org.kde.kirigami as Kirigami

// 顶栏通知入口。外观与 Clipboard / Network / Bluetooth 一致，统一来自 BarButton。
//
// 以前这里是 Process { command: ["qs","--path",".../Wallpaper/Notif.qml","ipc","call","notif","open"] }：
// 每点一次都会另起一个 qs 进程去开另一个进程里的通知中心，那个子进程还持有
// org.freedesktop.Notifications 这个名字，和主进程抢 D-Bus（应用发通知会时好时坏）。
// 现在通知中心就在本进程里，点按钮只是切一个布尔值。
BarButton {
    id: root

    readonly property bool dnd: NotificationManager.dnd
    readonly property int notifCount: NotificationManager.count

    checked: WidgetState.notifOpen
    icon: root.dnd ? "notifications-disabled-symbolic" : (root.notifCount > 0 ? "notifications-active-symbolic" : "notifications-symbolic")
    iconSize: Kirigami.Units.gridUnit * 0.9
    // 免打扰时不报未读数；为 0 时 badge 为空 → 整段隐藏
    badge: (root.notifCount > 0 && !root.dnd) ? String(root.notifCount) : ""
    contentColor: root.dnd ? Kirigami.Theme.disabledTextColor : (WidgetState.notifOpen ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor)

    onClicked: WidgetState.notifOpen = !WidgetState.notifOpen

    // --- 通知中心面板 ---
    NotificationWidget {
        id: popup
        anchorItem: root
        visible: WidgetState.notifOpen
        onCloseRequested: WidgetState.notifOpen = false
        // 面板因点击外部 / 合成器 popup_done 自己关掉时，把全局状态一起收回。
        // 否则 WidgetState.notifOpen 停在 true，下一次点击只是把它改回 false，
        // 面板仍然关着，用户会感觉"要点两次才打开"。
        onClosed: WidgetState.notifOpen = false
    }
}