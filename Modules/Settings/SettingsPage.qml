import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// 设置页容器：页头（图标 + 标题）+ 可滚动内容。
// 页面内容直接写在里面（SettingsPage { FormCard.FormCard { ... } }）。
Item {
    id: root

    property string title: ""
    property string icon: ""
    property string description: ""
    default property alias content: body.data

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        // ---------- 页头 ----------
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                visible: root.icon !== ""
                source: root.icon
                implicitWidth: Kirigami.Units.iconSizes.medium
                implicitHeight: implicitWidth
                color: Kirigami.Theme.highlightColor
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Kirigami.Heading {
                    text: root.title
                    level: 2
                    Layout.fillWidth: true
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

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        // ---------- 内容 ----------
        // Flickable 里的 ColumnLayout：FormCard 的 Layout.fillWidth 靠它生效
        Flickable {
            id: flick

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: body.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: body

                width: flick.width
                spacing: Kirigami.Units.largeSpacing
            }

            ScrollBar.vertical: ScrollBar {
                policy: flick.contentHeight > flick.height + 1 ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }
        }
    }
}