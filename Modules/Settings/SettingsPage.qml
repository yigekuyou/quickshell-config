import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// 设置页容器：标题行 + 可滚动内容。
// 页面内容用默认属性塞进来即可（SettingsPage { ... }）。
Item {
    id: root

    property string title: ""
    property string icon: ""
    default property alias content: body.data

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.mediumSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.mediumSpacing

            Kirigami.Icon {
                source: root.icon
                implicitWidth: Kirigami.Units.iconSizes.medium
                implicitHeight: implicitWidth
                color: Kirigami.Theme.highlightColor
            }

            Kirigami.Heading {
                text: root.title
                level: 3
                Layout.fillWidth: true
            }
        }

        Flickable {
            id: flick

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: body.implicitHeight + Kirigami.Units.largeSpacing
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: body

                width: flick.width
                spacing: Kirigami.Units.mediumSpacing
            }

            // 细滚动条：内容超出时才出现
            ScrollBar.vertical: ScrollBar {
                policy: flick.contentHeight > flick.height + 1 ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }
        }
    }
}