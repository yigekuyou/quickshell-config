pragma Singleton
import Quickshell
import org.kde.kirigami as Kirigami
Singleton {
    // ================= 原有配置 (保持不变) =================
    readonly property string fontFamily: Kirigami.Theme.defaultFont
    readonly property string fontFamilyMono: "Monospace"
    readonly property real cornerRadius: Kirigami.Units.gridUnit * 0.5
    readonly property real barHeight: Kirigami.Units.gridUnit * 1.6
}
