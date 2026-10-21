import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// ============================================================================
// 可折叠的“思考”块。
// 对应 dots-hyprland 的 MessageThinkBlock：未完成时顶部转圈 + “思考中…”，
// 完成后可点击展开 / 收起。背景用 Kirigami 的主题色，不自己画阴影。
// ============================================================================
Item {
    id: root

    property string text: ""
    property bool done: false

    // 默认展开，方便看效果；点右上角箭头收起
    property bool collapsed: false

    Layout.fillWidth: true
    implicitHeight: column.implicitHeight

    Rectangle {
        anchors.fill: parent
        radius: Kirigami.Units.cornerRadius
        color: Kirigami.Theme.alternateBackgroundColor
        border.width: 1
        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.08)

        ColumnLayout {
            id: column
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                // 没想完的时候转圈
                Kirigami.Icon {
                    source: "view-refresh"
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                    color: Kirigami.Theme.disabledTextColor
                    RotationAnimator on rotation {
                        running: !root.done
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 1100
                    }
                }

                Label {
                    text: root.done ? qsTr("已推理") : qsTr("思考中…")
                    color: Kirigami.Theme.disabledTextColor
                    font: Kirigami.Theme.smallFont
                    Layout.alignment: Qt.AlignVCenter
                }

                Item {
                    Layout.fillWidth: true
                }

                ToolButton {
                    visible: root.done
                    padding: 0
                    implicitWidth: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing * 2
                    implicitHeight: implicitWidth
                    icon.name: root.collapsed ? "go-down" : "go-up"
                    ToolTip.text: root.collapsed ? qsTr("展开") : qsTr("收起")
                    ToolTip.visible: hovered
                    onClicked: root.collapsed = !root.collapsed
                }
            }

            Item {
                id: thinkContent
                Layout.fillWidth: true
                implicitHeight: root.done && !root.collapsed ? thinkText.implicitHeight : 0
                clip: true

                Behavior on implicitHeight {
                    NumberAnimation {
                        duration: Kirigami.Units.longDuration
                        easing.type: Easing.OutQuad
                    }
                }

                TextArea {
                    id: thinkText
                    width: thinkContent.width
                    height: Math.max(implicitHeight, thinkContent.height)
                    readOnly: true
                    wrapMode: Text.Wrap
                    text: root.text
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                    background: null
                    padding: 0
                }
            }
        }
    }
}
