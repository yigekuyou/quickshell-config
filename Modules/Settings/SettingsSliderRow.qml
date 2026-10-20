import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard

// 设置行：滑块。value 由外部模型驱动，用户拖动时发 moved(real)。
// 排版交给 ColumnLayout：标题 + 数值 + 说明一行，滑块一行。
FormCard.AbstractFormDelegate {
    id: root

    // text 用继承的（ItemDelegate / AbstractButton 自带）
    property string description: ""
    property string iconName: ""
    property real from: 0
    property real to: 1
    property real stepSize: 0
    property real value: 0
    property int decimals: 0
    property string suffix: ""

    signal moved(real value)

    readonly property string displayValue: root.decimals > 0
        ? root.value.toFixed(root.decimals)
        : String(Math.round(root.value))

    Layout.fillWidth: true

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
                color: Kirigami.Theme.textColor
                Layout.alignment: Qt.AlignVCenter
            }

            Label {
                Layout.fillWidth: true
                text: root.text
                elide: Text.ElideRight
                maximumLineCount: 1
                color: Kirigami.Theme.textColor
            }

            Label {
                text: root.displayValue + root.suffix
                font.weight: Font.DemiBold
                color: Kirigami.Theme.highlightColor
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

        Slider {
            id: slider

            Layout.fillWidth: true
            from: root.from
            to: root.to
            stepSize: root.stepSize
            value: root.value
            // 拖动 / 点击 / 键盘都算用户操作
            onMoved: root.moved(value)
        }
    }

    // 拖动后 Slider 的 value binding 会断，模型侧再变时同步回来
    onValueChanged: {
        if (!slider.pressed && slider.value !== root.value)
            slider.value = root.value;
    }
}