import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Config
import qs.Services
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard

// 空闲策略：锁屏 / 息屏 / 睡眠。由 Wallpaper/Load.qml 里的 IdleMonitor 消费
// （Config/Idle.qml 只是 settings.json 的只读映射）。
SettingsPage {
    id: root

    title: qsTr("空闲")
    icon: "preferences-desktop-screensaver"

    FormCard.FormCard {
        Layout.fillWidth: true

        SettingsSwitchRow {
            text: qsTr("自动锁屏")
            description: qsTr("空闲到设定时间后启动锁屏")
            iconName: "system-lock-screen"
            switchOn: Settings.idle.lock
            onSwitchToggled: on => Settings.idle.lock = on
        }

        SettingsSwitchRow {
            text: qsTr("息屏（DPMS）")
            description: qsTr("关闭显示器输出，动一下鼠标就回来")
            iconName: "video-display"
            switchOn: Settings.idle.dpms
            onSwitchToggled: on => Settings.idle.dpms = on
        }

        SettingsSwitchRow {
            text: qsTr("自动睡眠")
            description: qsTr("调用 systemctl suspend")
            iconName: "system-suspend"
            switchOn: Settings.idle.sleep
            onSwitchToggled: on => Settings.idle.sleep = on
        }
    }

    FormCard.FormCard {
        Layout.fillWidth: true

        SettingsSliderRow {
            text: qsTr("锁屏等待")
            description: qsTr("空闲多久后锁屏")
            from: 30
            to: 1800
            stepSize: 30
            value: Settings.idle.lockTimeout
            suffix: " " + qsTr("秒")
            onMoved: value => Settings.idle.lockTimeout = Math.round(value / 30) * 30
        }

        SettingsSliderRow {
            text: qsTr("息屏等待")
            description: qsTr("空闲多久后关闭显示器")
            from: 30
            to: 1800
            stepSize: 30
            value: Settings.idle.dpmsTimeout
            suffix: " " + qsTr("秒")
            onMoved: value => Settings.idle.dpmsTimeout = Math.round(value / 30) * 30
        }

        SettingsSliderRow {
            text: qsTr("睡眠等待")
            description: qsTr("空闲多久后挂起系统")
            from: 60
            to: 3600
            stepSize: 60
            value: Settings.idle.sleepTimeout
            suffix: " " + qsTr("秒")
            onMoved: value => Settings.idle.sleepTimeout = Math.round(value / 60) * 60
        }
    }

    Label {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        text: qsTr("息屏 / 睡眠由 Wallpaper/Load.qml 的 IdleMonitor 执行，修改立即生效。")
        wrapMode: Text.WordWrap
        font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.65)
        color: Kirigami.Theme.disabledTextColor
    }
}