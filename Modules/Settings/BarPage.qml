import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Config
import qs.Services
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard

// 状态栏（顶栏）几何与密度。
// 所有值都是 gridUnit 的倍数，写进 settings.json 的 bar 段，
// Config/Sizes.qml 直接读它，所以拖动滑块顶栏会立刻跟着变。
SettingsPage {
    id: root

    title: qsTr("状态栏")
    icon: "preferences-desktop-theme"

    SettingsGroup {

        title: qsTr("尺寸")

        SettingsSliderRow {
            text: qsTr("高度")
            description: qsTr("实际高度 %1 px（跟随系统字号缩放）").arg(Math.round(Sizes.barHeight))
            from: 1.0
            to: 2.6
            stepSize: 0.05
            decimals: 2
            value: Settings.bar.height
            onMoved: value => Settings.bar.height = Math.round(value * 20) / 20
        }

        SettingsSliderRow {
            text: qsTr("圆角")
            description: qsTr("实际圆角 %1 px").arg(Math.round(Sizes.cornerRadius))
            from: 0
            to: 1.2
            stepSize: 0.05
            decimals: 2
            value: Settings.bar.cornerRadius
            onMoved: value => Settings.bar.cornerRadius = Math.round(value * 20) / 20
        }

    }

    FormCard.FormHeader {
        title: qsTr("左侧（应用菜单 / 工作区 / 剪贴板 / 设置）")
    }

    SectionDensity {
        section: "left"
    }

    SettingsGroup {

        title: qsTr("内容")

        SettingsSwitchRow {
            text: qsTr("显示文字")
            description: qsTr("关闭后只保留图标：音量百分比、网络名、SysMonitor 的 CPU/温度/内存数值都会隐藏")
            iconName: "format-text-bold-symbolic"
            switchOn: Settings.bar.labels
            onSwitchToggled: on => Settings.bar.labels = on
        }

        SettingsSwitchRow {
            text: qsTr("图标圆环")
            description: qsTr("把百分比画成图标外圈的进度环（音量、SysMonitor 等）")
            iconName: "media-record-symbolic"
            switchOn: Settings.bar.ring
            onSwitchToggled: on => Settings.bar.ring = on
        }
    }

    SettingsGroup {

        title: qsTr("圆环")

        SettingsSliderRow {
            text: qsTr("环大小")
            description: qsTr("环直径 = 图标 × 倍数，但不超过栏高（当前上限约 %1 px）。图标 %2 px，环 %3 px")
                .arg(Math.round(Sizes.barHeight - 2))
                .arg(Math.round(Sizes.secIcon("right")))
                .arg(Math.round(Sizes.ringSize(Sizes.secIcon("right"))))
            iconName: "media-record-symbolic"
            from: 0.9
            to: 2.0
            stepSize: 0.05
            decimals: 2
            value: Settings.bar.ringScale
            wired: Settings.bar.ring
            onMoved: value => Settings.bar.ringScale = Math.round(value * 20) / 20
        }

        SettingsSliderRow {
            text: qsTr("线宽")
            description: qsTr("数值越小越精致，太小会碎成点")
            iconName: "transform-scale-horizontal"
            from: 1.0
            to: 3.0
            stepSize: 0.1
            decimals: 1
            value: Settings.bar.ringWidth
            suffix: " px"
            wired: Settings.bar.ring
            onMoved: value => Settings.bar.ringWidth = Math.round(value * 10) / 10
        }

        SettingsSliderRow {
            text: qsTr("底环浓度")
            description: qsTr("未走完那圈的透明度，0 = 只画进度弧")
            iconName: "color-management"
            from: 0
            to: 0.5
            stepSize: 0.02
            decimals: 2
            value: Settings.bar.ringTrackOpacity
            wired: Settings.bar.ring
            onMoved: value => Settings.bar.ringTrackOpacity = Math.round(value * 50) / 50
        }
    }

    FormCard.FormHeader {
        title: qsTr("右侧（托盘 / 音量 / 网络 / 蓝牙 / 通知）")
    }

    SectionDensity {
        section: "right"
    }

    SettingsGroup {

        title: qsTr("默认值")

        // 说明条改用统一组件（InlineMessage），不再是“无背景表单行”
        SettingsNote {
            text: qsTr("修改会立即生效并写入 %1").arg(Settings.path)
        }

        FormCard.FormButtonDelegate {
            text: qsTr("恢复默认几何")
            description: qsTr("高度 / 圆角 / 圆环参数回到初始值")
            icon.name: "edit-undo"
            onClicked: {
                Settings.bar.height = 1.4;
                Settings.bar.cornerRadius = 0.5;
                Settings.bar.ringScale = 1.3;
                Settings.bar.ringWidth = 1.6;
                Settings.bar.ringTrackOpacity = 0.16;
            }
        }
    }
}
