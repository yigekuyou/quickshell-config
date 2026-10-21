import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// ============================================================================
// 单条聊天消息。
// 参考dots-hyprland 的 AiMessage.qml（header 放角色徽章 + 操作按钮，
// contentItem 放消息块），但整个换成 Kirigami.AbstractCard：
//   header      角色 + 时间 + 生成状态 + 复制 / 重新生成 / 删除
//   contentItem 思考块（ThinkBlock）+ 正文（markdown TextArea）
// ============================================================================
Kirigami.AbstractCard {
    id: card

    // ListView / ListModel 自动注入
    required property int index
    required property string mrole
    required property string content
    required property string thinking
    required property bool thinkingDone
    required property bool done
    required property string time

    // 由 GooseWindow 注入，用来执行 复制 / 删除 / 重新生成
    property var store

    showClickFeedback: false

    readonly property bool isUser: mrole === "user"
    readonly property bool isAssistant: mrole === "assistant"
    readonly property bool isStreaming: !card.done

    readonly property string roleName: {
        if (isUser)
            return qsTr("我")
        if (isAssistant)
            return qsTr("Goose")
        return qsTr("系统")
    }
    readonly property string roleIcon: {
        if (isUser)
            return "user-identity"
        if (isAssistant)
            return "im-user"
        return "system-run"
    }
    readonly property color roleColor: {
        if (isUser)
            return Kirigami.Theme.highlightColor
        if (isAssistant)
            return Kirigami.Theme.positiveTextColor
        return Kirigami.Theme.disabledTextColor
    }

    // ==================== 头部：角色 + 时间 + 操作 ====================
    header: RowLayout {
        spacing: Kirigami.Units.smallSpacing

        // 角色徽章（对应 AiMessage 里 colSecondaryContainer 那一条）
        Rectangle {
            radius: Kirigami.Units.cornerRadius
            color: Qt.alpha(card.roleColor, 0.15)
            implicitWidth: badgeRow.implicitWidth + Kirigami.Units.smallSpacing * 2
            implicitHeight: badgeRow.implicitHeight + Kirigami.Units.smallSpacing
            Layout.alignment: Qt.AlignVCenter

            RowLayout {
                id: badgeRow
                anchors.centerIn: parent
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: card.roleIcon
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                    color: card.roleColor
                }

                Label {
                    text: card.roleName
                    color: card.roleColor
                    font.weight: Font.DemiBold
                }
            }
        }

        Label {
            text: card.time
            color: Kirigami.Theme.disabledTextColor
            font: Kirigami.Theme.smallFont
            Layout.alignment: Qt.AlignVCenter
        }

        // 生成中的状态提示
        Label {
            visible: card.isStreaming
            text: card.thinking !== "" && !card.thinkingDone ? qsTr("思考中…") : qsTr("输入中…")
            color: Kirigami.Theme.disabledTextColor
            font: Kirigami.Theme.smallFont
            Layout.alignment: Qt.AlignVCenter
        }

        Item {
            Layout.fillWidth: true
        }

        ToolButton {
            id: copyButton
            icon.name: copied ? "checkmark" : "edit-copy"
            property bool copied: false
            ToolTip.text: qsTr("复制")
            ToolTip.visible: hovered
            onClicked: {
                if (card.store)
                    card.store.copyMessage(card.index)
                copied = true
                copyTimer.restart()
            }
            Timer {
                id: copyTimer
                interval: 1500
                repeat: false
                onTriggered: copyButton.copied = false
            }
        }

        ToolButton {
            id: regenButton
            visible: card.isAssistant
            icon.name: "view-refresh"
            ToolTip.text: qsTr("重新生成")
            ToolTip.visible: hovered
            onClicked: {
                if (card.store && !card.store.busy)
                    card.store.regenerate(card.index)
            }
        }

        ToolButton {
            id: deleteButton
            icon.name: "edit-delete"
            ToolTip.text: qsTr("删除")
            ToolTip.visible: hovered
            onClicked: {
                if (card.store)
                    card.store.removeMessage(card.index)
            }
        }
    }

    // ==================== 正文 ====================
    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        ThinkBlock {
            Layout.fillWidth: true
            visible: card.thinking !== ""
            text: card.thinking
            done: card.thinkingDone
        }

        TextArea {
            id: body
            Layout.fillWidth: true
            visible: card.content.length > 0
            readOnly: true
            selectByMouse: true
            textFormat: TextEdit.MarkdownText
            wrapMode: Text.Wrap
            text: card.content + (card.isStreaming ? " ▋" : "")
            color: Kirigami.Theme.textColor
            background: null
            padding: 0
        }
    }
}
