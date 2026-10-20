import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard

// 灵动岛（顶栏中间那个浮动面板）的尺寸设置。
// 全部是 gridUnit 的倍数，改完立刻生效；状态切换只改 root 的 width/height/radius，
// 所以这里调的就是运行时真实的几何。
SettingsPage {
    id: root

    title: qsTr("灵动岛")
    icon: "preferences-desktop-effects"

    FormCard.FormHeader {
        title: qsTr("收起 / 展开")
    }

    SettingsGroup {

        title: qsTr("尺寸")

        SettingsSliderRow {
            text: qsTr("收起宽度")
            description: qsTr("平时只露一条，实际 %1 px").arg(Math.round(Kirigami.Units.gridUnit * Settings.island.collapsedWidth))
            from: 6
            to: 30
            stepSize: 1
            decimals: 0
            value: Settings.island.collapsedWidth
            onMoved: value => Settings.island.collapsedWidth = Math.round(value)
        }

        SettingsSliderRow {
            text: qsTr("收起高度")
            description: qsTr("建议与栏高一致，实际 %1 px").arg(Math.round(Kirigami.Units.gridUnit * Settings.island.collapsedHeight))
            from: 1
            to: 6
            stepSize: 0.5
            decimals: 1
            value: Settings.island.collapsedHeight
            onMoved: value => Settings.island.collapsedHeight = Math.round(value * 2) / 2
        }

        SettingsSliderRow {
            text: qsTr("展开宽度")
            description: qsTr("媒体面板，实际 %1 px").arg(Math.round(Kirigami.Units.gridUnit * Settings.island.expandedWidth))
            from: 14
            to: 40
            stepSize: 1
            decimals: 0
            value: Settings.island.expandedWidth
            onMoved: value => Settings.island.expandedWidth = Math.round(value)
        }

        SettingsSliderRow {
            text: qsTr("展开高度")
            description: qsTr("媒体面板，实际 %1 px").arg(Math.round(Kirigami.Units.gridUnit * Settings.island.expandedHeight))
            from: 6
            to: 24
            stepSize: 1
            decimals: 0
            value: Settings.island.expandedHeight
            onMoved: value => Settings.island.expandedHeight = Math.round(value)
        }

        SettingsSliderRow {
            text: qsTr("歌词条宽度")
            description: qsTr("单行歌词，实际 %1 px").arg(Math.round(Kirigami.Units.gridUnit * Settings.island.lyricsWidth))
            from: 14
            to: 44
            stepSize: 1
            decimals: 0
            value: Settings.island.lyricsWidth
            onMoved: value => Settings.island.lyricsWidth = Math.round(value)
        }

        SettingsSliderRow {
            text: qsTr("歌词条高度")
            description: qsTr("实际 %1 px").arg(Math.round(Kirigami.Units.gridUnit * Settings.island.lyricsHeight))
            from: 1
            to: 6
            stepSize: 0.5
            decimals: 1
            value: Settings.island.lyricsHeight
            onMoved: value => Settings.island.lyricsHeight = Math.round(value * 2) / 2
        }

        SettingsSliderRow {
            text: qsTr("圆角")
            description: qsTr("大面板会自动放大 1.5 倍")
            from: 0.2
            to: 2.5
            stepSize: 0.1
            decimals: 1
            value: Settings.island.radius
            onMoved: value => Settings.island.radius = Math.round(value * 10) / 10
        }
    }

    FormCard.FormHeader {
        title: qsTr("其它面板")
    }

    SettingsGroup {

        title: qsTr("仪表盘 / 授权")

        SettingsSliderRow {
            text: qsTr("仪表盘宽度")
            description: qsTr("课表 / 日历 / 系统信息，实际 %1 px").arg(Math.round(Kirigami.Units.gridUnit * Settings.island.dashboardWidth))
            from: 24
            to: 70
            stepSize: 1
            decimals: 0
            value: Settings.island.dashboardWidth
            onMoved: value => Settings.island.dashboardWidth = Math.round(value)
        }

        SettingsSliderRow {
            text: qsTr("仪表盘高度")
            description: qsTr("实际 %1 px").arg(Math.round(Kirigami.Units.gridUnit * Settings.island.dashboardHeight))
            from: 10
            to: 40
            stepSize: 1
            decimals: 0
            value: Settings.island.dashboardHeight
            onMoved: value => Settings.island.dashboardHeight = Math.round(value)
        }

        SettingsSliderRow {
            text: qsTr("授权宽度")
            description: qsTr("polkit 密码框，实际 %1 px").arg(Math.round(Kirigami.Units.gridUnit * Settings.island.authWidth))
            from: 20
            to: 50
            stepSize: 1
            decimals: 0
            value: Settings.island.authWidth
            onMoved: value => Settings.island.authWidth = Math.round(value)
        }

        SettingsSliderRow {
            text: qsTr("授权高度")
            description: qsTr("实际 %1 px").arg(Math.round(Kirigami.Units.gridUnit * Settings.island.authHeight))
            from: 8
            to: 30
            stepSize: 1
            decimals: 0
            value: Settings.island.authHeight
            onMoved: value => Settings.island.authHeight = Math.round(value)
        }
    }

    FormCard.FormHeader {
        title: qsTr("中间区密度")
    }

    SectionDensity {
        section: "center"
    }
}
