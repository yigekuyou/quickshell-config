pragma Singleton
import Quickshell
import org.kde.kirigami as Kirigami
Singleton {
    // ================= 原有配置 (保持不变) =================
	readonly property bool idlelock: true
	readonly property bool idlebacklight: false
	readonly property bool idledpms: true
	readonly property bool idlesleep: true
	readonly property real idlelocktime:600
	readonly property real idlebacklighttime:300
	readonly property real dpmsTimeout:60
	readonly property real sleepTimeout:60
}
