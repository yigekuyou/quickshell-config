import QtQuick
import Quickshell
import qs.Config
import Quickshell.Io
import org.kde.kirigami as Kirigami

Kirigami.ShadowedRectangle {
    id: root
    implicitHeight: Sizes.barHeight
    implicitWidth: layout.implicitWidth + Kirigami.Units.largeSpacing * 2

    // 使用 Kirigami 主题色，带透明度
    color: Qt.alpha(Kirigami.Theme.backgroundColor, 0.5)
    radius: Sizes.cornerRadius
    shadow.color: Qt.rgba(0, 0, 0, 0.2)
    shadow.size: 10
    shadow.yOffset: 2
    border.width: 1
    border.color: Qt.alpha(Kirigami.Theme.dividerColor, 0.3)
    // --- 交互区域 ---
    Process {
	    id: notif
	    running: false
	    command: ["qs", "--path", Quickshell.env("XDG_CONFIG_HOME") + "/quickshell/Wallpaper/Notif.qml", "ipc", "call", "notif", "open"]
    }
    TapHandler {
	    acceptedButtons: Qt.LeftButton
	    onTapped: {
		    notif.startDetached();
	    }
    }
    // --- 图标内容 ---
    Kirigami.Icon {
        id: layout
        anchors.centerIn: parent
        source:"notifications-symbolic"
	color:Kirigami.Theme.activeTextColor
	implicitHeight:Kirigami.Units.iconSizes.small
	implicitWidth: implicitHeight
        // 铃铛图标 (Font Awesome)

    }
}
