import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard

// 设置行：下拉框（Plasma 的 OptionItem + ComboBox）。
// model 传 [{ text, value }, ...]；选中后用 selected(value) 写回模型。
FormCard.AbstractFormDelegate {
    id: root

    property string description: ""
    property string iconName: ""
    // [{ text: "…", value: 0 }, …]
    property var model: []
    property var currentValue: undefined
    property bool wired: true

    signal selected(var value)

    Layout.fillWidth: true

    readonly property int currentIndex: {
        for (let i = 0; i < root.model.length; i++) {
            if (root.model[i].value === root.currentValue)
                return i;
        }
        return -1;
    }

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

            ComboBox {
                id: combo

                enabled: root.wired
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                model: root.model.map(entry => entry.text)
                currentIndex: root.currentIndex
                onActivated: index => {
                    if (index >= 0 && root.model[index])
                        root.selected(root.model[index].value);
                }
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
}
