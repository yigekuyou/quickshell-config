import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard

// 一个分区（left / center / right）的密度三项：图标大小 / 内边距 / 按钮间距。
// 左、中、右三块在设置里各用一份，互相独立。
// 本身是一张 FormCard，页面里用 FormCard.FormHeader 当标题即可。
FormCard.FormCard {
    id: root

    Layout.fillWidth: true
    // 和 SettingsGroup 一样放开 Kirigami 默认的 30 gridUnit（≈540px）宽度上限：
    // 不然同一页里左/右侧密度的卡片比其它卡片窄一截，一大一小。
    maximumWidth: Number.POSITIVE_INFINITY

    property string section: "left"

    SettingsSliderRow {
        text: qsTr("图标大小")
        description: qsTr("实际图标 %1 px").arg(Math.round(Sizes.secIcon(root.section)))
        from: 0.5
        to: 1.6
        stepSize: 0.02
        decimals: 2
        value: Settings.bar[root.section + "IconSize"]
        onMoved: value => Settings.bar[root.section + "IconSize"] = Math.round(value * 50) / 50
    }

    SettingsSliderRow {
        text: qsTr("内边距")
        description: qsTr("胶囊左右留白，实际 %1 px").arg(Math.round(Sizes.secPad(root.section)))
        from: 0
        to: 1.0
        stepSize: 0.02
        decimals: 2
        value: Settings.bar[root.section + "Padding"]
        onMoved: value => Settings.bar[root.section + "Padding"] = Math.round(value * 50) / 50
    }

    SettingsSliderRow {
        text: qsTr("按钮间距")
        description: qsTr("相邻部件之间，实际 %1 px").arg(Math.round(Sizes.secGap(root.section)))
        from: 0
        to: 0.8
        stepSize: 0.02
        decimals: 2
        value: Settings.bar[root.section + "Spacing"]
        onMoved: value => Settings.bar[root.section + "Spacing"] = Math.round(value * 50) / 50
    }
}
