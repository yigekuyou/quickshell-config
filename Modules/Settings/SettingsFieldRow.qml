import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// 一行“标签 + 控件”。
//
// Web 选项里 text / color / number / file 这几类控件都用它排：
//   * 左边是标签列（自动换行，长了不会变成省略号），标签下面可以带一行说明；
//   * 右边是控件，铺满剩下的宽度；
//   * 上下左右留出和 Kirigami 表单行一致的边距，一行行之间不会粘在一起。
//
// 用法：把控件直接写进里面就行，它们会被放进内部的 RowLayout。
//
//   SettingsFieldRow {
//       label: qsTr("背景色")
//       description: qsTr("留空表示跟随主题")
//       TextField { Layout.fillWidth: true }
//   }
ColumnLayout {
    id: root

    property string label: ""
    property string description: ""

    default property alias content: fieldRow.data

    Layout.fillWidth: true
    Layout.leftMargin: Kirigami.Units.largeSpacing
    Layout.rightMargin: Kirigami.Units.largeSpacing
    Layout.topMargin: Kirigami.Units.smallSpacing
    Layout.bottomMargin: Kirigami.Units.smallSpacing
    spacing: 0


    RowLayout {
        id: fieldRow

        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing

        // 标签列：固定一个舒服的宽度，字多了就换行；说明写在标签下面，
        // 和右侧控件顶部对齐，长说明也不会把控件挤扁。
        ColumnLayout {
            id: labelCol

            visible: root.label !== "" || root.description !== ""
            Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            Layout.maximumWidth: Kirigami.Units.gridUnit * 16
            Layout.alignment: Qt.AlignTop
            spacing: 0

            Label {
                Layout.fillWidth: true
                visible: root.label !== ""
                text: root.label
                font: Kirigami.Theme.defaultFont
                color: Kirigami.Theme.textColor
                wrapMode: Text.WordWrap
            }

            Label {
                Layout.fillWidth: true
                visible: root.description !== ""
                text: root.description
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
                wrapMode: Text.WordWrap
            }
        }
    }
}
