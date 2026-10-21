import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// ============================================================================
// 设置页里的说明条。所有“这不是一个选项，只是一段解释”的地方都走它。
//
// 以前有两种写法并存：
//   * 页里散落的 Label（字号/颜色/换行各自写一遍，页与页之间对不齐）；
//   * FormCard.AbstractFormDelegate { background: null } 这种 hack
//     （借表单行的布局放一段文字，行高和留白都不受控）。
// 现在统一成 Kirigami 自己的 InlineMessage：图标、留白、信息/警告配色都由
// 组件负责，和页面级的 InlineMessage 完全一致。
//
// 用法：
//   SettingsNote { text: qsTr("选项来自 project.json …") }
//   SettingsNote { text: … ; type: Kirigami.MessageType.Warning }
// ============================================================================
Kirigami.InlineMessage {
    id: root

    Layout.fillWidth: true
    // 卡片里自带留白，不然信息条会贴着卡片两侧的圆角
    Layout.leftMargin: Kirigami.Units.smallSpacing
    Layout.rightMargin: Kirigami.Units.smallSpacing
    Layout.topMargin: Kirigami.Units.smallSpacing * 0.5
    Layout.bottomMargin: Kirigami.Units.smallSpacing * 0.5
    visible: root.text !== ""
    type: Kirigami.MessageType.Information
    showCloseButton: false
}