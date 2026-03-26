pragma Singleton
import Quickshell
import org.kde.kirigami as Kirigami
Singleton {
    // ================= 原有配置 (保持不变) =================
    readonly property string fontFamily: Kirigami.Theme.defaultFont
    readonly property string fontFamilyMono: Mono// 建议终端字体单独定义
    readonly property real cornerRadius: Kirigami.Units.gridUnit * 0.5
    readonly property real barHeight: Kirigami.Units.gridUnit * 1.6
}
