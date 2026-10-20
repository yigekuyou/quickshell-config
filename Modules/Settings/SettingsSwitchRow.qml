import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard

// 设置行：开关。switchOn 由外部模型（settings.json）驱动，用户拨动时发 switchToggled(bool)。
FormCard.AbstractFormDelegate {
    id: root

    // text 用继承的（ItemDelegate / AbstractButton 自带），不再重复声明
    property string description: ""
    property string iconName: ""
    // 不用 checked / toggled：FormCard.AbstractFormDelegate 继承自 ItemDelegate，
    // 这两个名字（AbstractButton.checked / toggled）已经被占用，重名会报
    // “Duplicate signal name / invalid override of property change signal”
    property bool switchOn: false

    signal switchToggled(bool on)

    Layout.fillWidth: true

    contentItem: RowLayout {
        spacing: Kirigami.Units.mediumSpacing

        Kirigami.Icon {
            visible: root.iconName !== ""
            source: root.iconName
            implicitWidth: Kirigami.Units.iconSizes.smallMedium
            implicitHeight: implicitWidth
            color: Kirigami.Theme.textColor
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Label {
                Layout.fillWidth: true
                text: root.text
                elide: Text.ElideRight
                maximumLineCount: 1
                color: Kirigami.Theme.textColor
            }

            Label {
                Layout.fillWidth: true
                visible: root.description !== ""
                text: root.description
                wrapMode: Text.WordWrap
                font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.65)
                color: Kirigami.Theme.disabledTextColor
            }
        }

        Switch {
            id: sw

            checked: root.switchOn
            onToggled: root.switchToggled(checked)
            Layout.alignment: Qt.AlignVCenter
        }
    }

    // Switch 被用户拨动后 binding 会断，模型侧再变时靠这里同步回去
    onSwitchOnChanged: {
        if (sw.checked !== root.switchOn)
            sw.checked = root.switchOn;
    }
}