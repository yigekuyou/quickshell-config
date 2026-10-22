import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard

// 设置行：「标签 + 描述 + 自定义控件」。
//
// 以前这行是手工 ColumnLayout（自带 leftMargin/rightMargin 又叠 FormCard 的
// 内边距），和同卡片里的 Switch/Slider/Combo 行（统一走 FormCard 的行内边距）
// 留白和行高都对不上 —— 同一张卡片里两套间距， visibly 一大一小。
// 现在和其他行一样基于 FormCard.AbstractFormDelegate，内边距/行高由
// FormCard 统一控制，版式与 SettingsComboRow 对齐：
//   * 第一行：标签（按文字宽度，最宽 16gu） + 控件（塞进来，铺满剩余宽度）
//   * 第二行：说明（整行宽，小号字，可换行）
//
// 用法：把控件直接写进里面就行，它们会被放进内部的 RowLayout。
//
//   SettingsFieldRow {
//       label: qsTr("背景色")
//       description: qsTr("留空表示跟随主题")
//       TextField { Layout.fillWidth: true }
//   }
FormCard.AbstractFormDelegate {
    id: root

    property string label: ""
    property string description: ""

    default property alias content: fieldRow.data

    Layout.fillWidth: true

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            id: fieldRow

            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Label {
                visible: root.label !== ""
                text: root.label
                color: Kirigami.Theme.textColor
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                // 标签长就换行，但不许超过 16gu，把宽度让给右侧控件
                Layout.maximumWidth: Kirigami.Units.gridUnit * 16
                Layout.alignment: Qt.AlignVCenter
            }

            // 右侧控件（通过 default property 塞进来），铺满剩余宽度，
            // 与 SettingsComboRow 里下拉框同一位置
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
