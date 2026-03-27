pragma Singleton
import Quickshell
import org.kde.kirigami as Kirigami
Singleton {
    // ================= 原有配置 (保持不变) =================
	readonly property bool idlelock: true
	readonly property bool idlebacklight: false
	readonly property bool idledpms: true
	readonly property bool idlesleep: true
	readonly property real idlelocktime:180
	readonly property real idlebacklighttime:300
	readonly property real dpmsTimeout:120
	readonly property real sleepTimeout:300
}
