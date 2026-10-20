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
    }
}