import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard

// 一组设置：标题条 + 卡片。对应 Plasma 设置界面里的 OptionGroup
// （问题的分组框：上面一行标题，下面一张框住的行列表）。
// 行直接用 FormCard 的 delegate（SettingsSwitchRow / SettingsSliderRow / …）：
//
//   SettingsGroup {
//       title: qsTr("声音")
//       SettingsSliderRow { ... }
//       SettingsSwitchRow { ... }
//   }
ColumnLayout {
    id: root

    Layout.fillWidth: true
    spacing: 0

    property string title: ""

    default property alias content: card.delegates

    FormCard.FormHeader {
        Layout.fillWidth: true
        title: root.title
        visible: root.title !== ""
    }

    FormCard.FormCard {
        id: card

        Layout.fillWidth: true
        // Kirigami 的 FormCard 默认把宽度限制在 30 gridUnit（≈540px）再居中：
        // 1920 的窗口里就缩成中间窄窄一条，和左对齐的页头、标签栏完全对不上，
        // 行里的下拉框也被挤成一截。这里放开上限，让它跟着页面宽度走。
        maximumWidth: Number.POSITIVE_INFINITY
    }

}