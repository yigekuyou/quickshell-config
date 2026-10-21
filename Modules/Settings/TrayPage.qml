import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Config
import qs.Services
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard

// 顶栏右侧那一组（系统托盘 + 状态指示）的密度与外观。
// 数值是 gridUnit 的倍数，写进 settings.json 的 bar 段，改动即时生效。
SettingsPage {
    id: root

    title: qsTr("托盘")
    icon: "preferences-system-symbolic"

    // 预设只动右侧三项（高度是全局的，不在这里改）
    function applyPreset(iconSize, padding, spacing) {
        Settings.bar.rightIconSize = iconSize;
        Settings.bar.rightPadding = padding;
        Settings.bar.rightSpacing = spacing;
    }

    // 页首说明：Kirigami 的行内信息条，和「壁纸」页的提示同一个组件
    SettingsGroup {
        title: qsTr("右侧外观")

        SettingsNote {
            text: qsTr("密度、显示文字、图标圆环都在「状态栏」页；这页只做一键预设。")
        }
    }

    SettingsGroup {

        title: qsTr("预设")

        FormCard.FormButtonDelegate {
            text: qsTr("紧凑")
            description: qsTr("图标 0.78 / 留白 0.22 / 间距 0.08")
            icon.name: "zoom-out"
            onClicked: root.applyPreset(0.78, 0.22, 0.08)
        }

        FormCard.FormButtonDelegate {
            text: qsTr("标准")
            description: qsTr("图标 0.85 / 留白 0.28 / 间距 0.12")
            icon.name: "zoom-original"
            onClicked: root.applyPreset(0.85, 0.28, 0.12)
        }

        FormCard.FormButtonDelegate {
            text: qsTr("舒适")
            description: qsTr("图标 1.00 / 留白 0.50 / 间距 0.24")
            icon.name: "zoom-in"
            onClicked: root.applyPreset(1.0, 0.5, 0.24)
        }
    }
}
