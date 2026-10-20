import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kirigami.delegates as KDelegate

// 设置行：开关。
// 直接用 Kirigami 自带的 SwitchSubtitleDelegate（QQC2.SwitchDelegate 的子类）：
// 悬停/按下/焦点/无障碍/ToolTip 都是标准行为，这里只做「外部模型 ↔ Switch」的同步。
//
// 为什么还需要这一层：用户拨动 Switch 会破坏 checked 的绑定，所以模型再变时
// 要在 onSwitchOnChanged 里手动写回（下面的写法就是标准做法）。
KDelegate.SwitchSubtitleDelegate {
    id: root

    // text / subtitle 用继承的
    property alias description: root.subtitle
    property alias iconName: root.icon.name

    // 不用 checked / toggled：QQC2.SwitchDelegate 已经占了这两个名字
    property bool switchOn: false
    signal switchToggled(bool on)

    Layout.fillWidth: true

    checked: root.switchOn
    onToggled: root.switchToggled(root.checked)
    onSwitchOnChanged: {
        if (root.checked !== root.switchOn)
            root.checked = root.switchOn;
    }
}