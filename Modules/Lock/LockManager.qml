import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services
import Quickshell.Services.Pam

Item {
	id: root
	property alias pam :pam

	// --- 播放参数 ---
	property int fps: 60
	property real speed: 1.0
	property bool muted: true
	PamContext {
		id: pam
	}
	Loader {
		id: lockLoader
		active: false
		source:"Lock.qml"
		Connections {
			enabled: lockLoader.status === Loader.Ready
			target: lockLoader.item
			function onUnlocked() {
				lockLoader.active = false
			}
		}
	}
	IpcHandler {
		target: "lock"

		function open() {
			if (!lockLoader.active) {
				lockLoader.active = true
				return "LOCKED"
			}
			return "ALREADY_LOCKED"
		}
	}
}
