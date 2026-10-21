import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// 设置页容器：页头（图标 + 标题 + 说明）+ 可滚动内容。
// 页面内容直接写在里面（SettingsPage { FormCard.FormCard { ... } }）。
//
// 注意这里的 `data: [ ... ]`：本组件的默认属性被 aliases 给了 body.data
// （页面内容要进 Flickable 里的 ColumnLayout），所以自身这套页头 + Flickable
// 必须用 data: 显式塞给 Item，否则会被默认属性一起吸进 body，造成布局环。
Item {
    id: root

    property string title: ""
    property string icon: ""
    property string description: ""
    default property alias content: body.data

    data: [
        ColumnLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.largeSpacing

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
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        color: Kirigami.Theme.disabledTextColor
                    }
                }
            }

            Kirigami.Separator {
                Layout.fillWidth: true
            }

            Flickable {
                id: flick

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                // 内容不足一屏时也要占满视口：页面里带 fillHeight 的块（列表 /
                // 网格 / 内层 Flickable）才有地方铺开，不会被裁在窗口底部。
                contentHeight: Math.max(flick.height, body.implicitHeight)
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: body

                    width: flick.width
                    height: Math.max(flick.height, implicitHeight)
                    spacing: Kirigami.Units.largeSpacing
                }

                ScrollBar.vertical: ScrollBar {
                    policy: flick.contentHeight > flick.height + 1 ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                }
            }
        }
    ]
}