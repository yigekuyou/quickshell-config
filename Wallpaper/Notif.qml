import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import qs.Config
import qs.Modules.Notifications
import qs.Widget

ShellRoot {
	Variants {model: Quickshell.screens
		PanelWindow {
			id: barWindow
			WlrLayershell.namespace:"notifPanel"
			WlrLayershell.layer: WlrLayer.Bottom
			required property var modelData
			screen: modelData
			anchors {
				top: true
				right: true
			}
			color: "transparent"
			implicitHeight: 0
		NotificationWidget {
			id: notifPanel
			visible: false
		}
		NotificationPopupManager {}
		IpcHandler {
			target: "notif"
			function open() {
				notifPanel.visible=!notifPanel.visible
			}
		}
		}
	}
}
