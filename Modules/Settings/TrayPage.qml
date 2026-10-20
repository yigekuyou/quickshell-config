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

    FormCard.FormHeader {
        title: qsTr("右侧外观")
    }

    FormCard.FormCard {

        FormCard.AbstractFormDelegate {
            Layout.fillWidth: true
            background: null

            contentItem: Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr("图标大小 / 内边距 / 按钮间距见「状态栏 → 右侧」。")
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                color: Kirigami.Theme.disabledTextColor
            }
        }
    }

    SettingsGroup {

        title: qsTr("类型")

        SettingsSwitchRow {
            text: qsTr("显示文字")
            description: qsTr("关闭后只保留图标（音量百分比等文字会隐藏）")
            iconName: "format-text-bold-symbolic"
            switchOn: Settings.bar.labels
            onSwitchToggled: on => Settings.bar.labels = on
        }

        SettingsSwitchRow {
            text: qsTr("图标圆环")
            description: qsTr("把百分比画成图标外圈的进度环（音量等）")
            iconName: "media-record-symbolic"
            switchOn: Settings.bar.ring
            onSwitchToggled: on => Settings.bar.ring = on
        }
    }

    SettingsGroup {

        title: qsTr("预设")

        FormCard.AbstractFormDelegate {
            Layout.fillWidth: true
            background: null

            contentItem: ColumnLayout {
                spacing: Kirigami.Units.smallSpacing

                Label {
                    Layout.fillWidth: true
                    text: qsTr("一键写入右侧的图标 / 留白 / 间距")
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    color: Kirigami.Theme.disabledTextColor
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Button {
                        text: qsTr("紧凑")
                        onClicked: root.applyPreset(0.78, 0.22, 0.08)
                    }

                    Button {
                        text: qsTr("标准")
                        onClicked: root.applyPreset(0.85, 0.28, 0.12)
                    }

                    Button {
                        text: qsTr("舒适")
                        onClicked: root.applyPreset(1.0, 0.5, 0.24)
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
