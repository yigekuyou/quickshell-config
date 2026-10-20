import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Config
import qs.Services
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard

// 托盘（顶栏右侧那排图标按钮）的密度与外观。
// 数值都是 gridUnit 的倍数，写进 settings.json 的 bar 段，
// Config/Sizes.qml 立刻生效。
SettingsPage {
    id: root

    title: qsTr("托盘")
    icon: "preferences-system-symbolic"

    function applyPreset(height, iconSize, padding, spacing) {
        Settings.bar.height = height;
        Settings.bar.iconSize = iconSize;
        Settings.bar.padding = padding;
        Settings.bar.spacing = spacing;
    }

    SettingsGroup {

        title: qsTr("密度")

        SettingsSliderRow {
            text: qsTr("图标大小")
            description: qsTr("实际图标 %1 px").arg(Math.round(Sizes.barIconSize))
            from: 0.55
            to: 1.4
            stepSize: 0.05
            decimals: 2
            value: Settings.bar.iconSize
            onMoved: value => Settings.bar.iconSize = Math.round(value * 20) / 20
        }

        SettingsSliderRow {
            text: qsTr("内边距")
            description: qsTr("胶囊左右留白，实际 %1 px").arg(Math.round(Sizes.barPadding))
            from: 0
            to: 0.9
            stepSize: 0.02
            decimals: 2
            value: Settings.bar.padding
            onMoved: value => Settings.bar.padding = Math.round(value * 50) / 50
        }

        SettingsSliderRow {
            text: qsTr("按钮间距")
            description: qsTr("相邻按钮之间，实际 %1 px").arg(Math.round(Sizes.barSpacing))
            from: 0
            to: 0.6
            stepSize: 0.02
            decimals: 2
            value: Settings.bar.spacing
            onMoved: value => Settings.bar.spacing = Math.round(value * 50) / 50
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
                    text: qsTr("一键写入上面几项（高度 + 图标 + 留白 + 间距）")
                    wrapMode: Text.WordWrap
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    color: Kirigami.Theme.disabledTextColor
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Button {
                        text: qsTr("紧凑")
                        onClicked: root.applyPreset(1.3, 0.78, 0.22, 0.08)
                    }

                    Button {
                        text: qsTr("标准")
                        onClicked: root.applyPreset(1.4, 0.85, 0.28, 0.12)
                    }

                    Button {
                        text: qsTr("舒适")
                        onClicked: root.applyPreset(1.6, 1.0, 0.55, 0.25)
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
