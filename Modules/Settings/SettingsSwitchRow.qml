import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard

// 设置行：开关。
//
// 原来用 KDelegate.SwitchSubtitleDelegate，而同卡片里的
// SettingsSliderRow / SettingsColorRow / SettingsComboRow /
// SettingsFieldRow 都基于 FormCard.AbstractFormDelegate —— 两套根类型的
// 隐式高度和内边距算法不同，混排时同一张卡片里行高一大一小。
// 现在统一成 AbstractFormDelegate，版式与其他行完全一致：
//   * 第一行：图标 + 标签 + 右侧 Switch
//   * 第二行：说明（整行宽，小号字，可换行）
// 对外 API 不变：text / description / iconName / switchOn / wired /
// switchToggled(bool)。
FormCard.AbstractFormDelegate {
    id: root

    // text 用继承的（ItemDelegate 自带）
    property string description: ""
    property string iconName: ""
    // 不用 checked / toggled：QQC2.SwitchDelegate 的语义不同，保持原有名字
    property bool switchOn: false
    // false = 该选项属于 WE 插件但当前渲染器不消费，整行置灰
    property bool wired: true

    signal switchToggled(bool on)

    Layout.fillWidth: true

    enabled: root.wired

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                visible: root.iconName !== ""
                source: root.iconName
                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                implicitHeight: implicitWidth
                color: root.wired ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                Layout.alignment: Qt.AlignVCenter
            }

            Label {
                Layout.fillWidth: true
                text: root.text
                elide: Text.ElideRight
                maximumLineCount: 1
                color: root.wired ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
            }

            Switch {
                id: sw

                enabled: root.wired
                checked: root.switchOn
                onToggled: root.switchToggled(sw.checked)
            }
        }

        Label {
            Layout.fillWidth: true
            visible: root.description !== ""
            text: root.description
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
        }
    }

    // 用户拨动 Switch 会覆盖 checked 的绑定，模型侧再变时在这里同步回来
    onSwitchOnChanged: {
        if (sw.checked !== root.switchOn)
            sw.checked = root.switchOn;
    }
}
