pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import org.kde.kirigami as Kirigami

// ============================================================================
// Goose 聊天窗口。
// 版式照 dots-hyprland 的 AiChat（顶部状态条 + 消息列表 + 底部输入区），
// 但整体换成 Kirigami 组件：消息卡是 Kirigami.AbstractCard，状态/提示用
// Kirigami.Chip，空列表用 Kirigami.PlaceholderMessage。
//
// 窗口本身是真 xdg toplevel（和 Modules/Settings/SettingsWindow.qml 一样），
// 合成器该怎么管就怎么管。打开方式：
//   qs ipc call goose toggle | open | close
//   qs ipc call goose send '你好'     （非交互式塞一句话进去）
//   qs ipc call goose clear
// ============================================================================
Kirigami.AbstractApplicationWindow {
    id: win

    // 在主 shell 里用就是一个受 WidgetState 控制的开关；
    // 独立跑（qs -p Apps/Goose/main.qml）时默认打开。
    property bool open: true
    visible: win.open

    title: qsTr("Goose · ACP 聊天")

    width: Kirigami.Units.gridUnit * 46
    height: Kirigami.Units.gridUnit * 40
    minimumWidth: Kirigami.Units.gridUnit * 32
    minimumHeight: Kirigami.Units.gridUnit * 26

    color: Kirigami.Theme.backgroundColor

    ChatStore {
        id: chatStore
    }

    onOpenChanged: {
        if (open)
            input.forceActiveFocus()
    }
    Component.onCompleted: input.forceActiveFocus()

    Shortcut {
        sequence: "Escape"
        onActivated: win.open = false
    }
    Shortcut {
        sequence: "Ctrl+L"
        onActivated: chatStore.clear()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---------- 标题行 + 状态条 ----------
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Heading {
                text: qsTr("Goose")
                level: 2
            }

            Kirigami.Chip {
                text: chatStore.busy ? qsTr("生成中…") : qsTr("演示模式 · 未连接 ACP")
                closable: false
                interactive: false
            }

            // 模型选择下拉框
            ComboBox {
                id: modelCombo
                model: chatStore.availableModels
                currentIndex: chatStore.availableModels.findIndex(m => m.id === chatStore.currentModel)
                displayText: chatStore.availableModels.find(m => m.id === chatStore.currentModel)?.name ?? chatStore.currentModel
                delegate: ItemDelegate {
                    required property int index
                    required property var modelData
                    width: modelCombo.popup.width
                    text: modelData.name
                    font: modelCombo.font
                    highlighted: modelCombo.highlightedIndex === index
                    onClicked: {
                        modelCombo.currentIndex = index
                        modelCombo.popup.close()
                    }
                }
                indicator: Kirigami.Icon {
                    source: "go-down"
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Kirigami.Units.smallSpacing
                }
                onCurrentIndexChanged: {
                    if (currentIndex >= 0)
                        chatStore.setModel(modelCombo.model[currentIndex].id)
                }
                ToolTip.text: qsTr("选择模型")
                ToolTip.visible: hovered
                Layout.preferredWidth: Kirigami.Units.gridUnit * 18
            }

            // 思考强度：Chip 组
            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                Repeater {
                    model: chatStore.effortOptions
                    delegate: Kirigami.Chip {
                        required property var modelData
                        text: modelData.label
                        icon.name: modelData.icon
                        closable: false
                        checkable: true
                        checked: chatStore.thinkingEffort === modelData.id
                        onClicked: chatStore.setThinkingEffort(modelData.id)
                        Binding on checked {
                            value: chatStore.thinkingEffort === modelData.id
                            restoreMode: Binding.RestoreBindingOrValue
                        }
                        ToolTip.text: qsTr("思考强度：%1").arg(modelData.label)
                        ToolTip.visible: hovered
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }

            ToolButton {
                icon.name: "edit-clear"
                ToolTip.text: qsTr("清空会话（Ctrl+L）")
                ToolTip.visible: hovered
                onClicked: chatStore.clear()
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        // ---------- 消息列表 ----------
        Item {
            id: listWrap
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                id: messageList
                anchors.fill: parent
                topMargin: Kirigami.Units.largeSpacing
                bottomMargin: Kirigami.Units.largeSpacing
                leftMargin: Kirigami.Units.largeSpacing
                rightMargin: Kirigami.Units.largeSpacing

                model: chatStore.messages
                spacing: Kirigami.Units.largeSpacing
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: 800

                ScrollBar.vertical: ScrollBar {}

                // 用户本来就在底部时，新消息 / 流式输出自动贴底
                onCountChanged: Qt.callLater(scrollIfPinned)
                onContentHeightChanged: Qt.callLater(scrollIfPinned)
                function scrollIfPinned() {
                    if (atYEnd)
                        positionViewAtEnd()
                }

                delegate: ChatMessage {
                    store: chatStore
                }
            }

            Kirigami.PlaceholderMessage {
                anchors.centerIn: parent
                visible: messageList.count === 0
                icon.name: "im-user"
                text: qsTr("和 Goose 聊聊天")
                explanation: qsTr("现在是演示模式，回复由本地模拟数据生成。")
                helpfulAction: Kirigami.Action {
                    text: qsTr("打个招呼")
                    icon.name: "document-send"
                    onTriggered: chatStore.send("你好，介绍一下你自己")
                }
            }

            // 列表没贴底时显示“回到底部”
            ToolButton {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Kirigami.Units.largeSpacing
                z: 1
                visible: messageList.count > 0 && !messageList.atYEnd
                icon.name: "go-down"
                ToolTip.text: qsTr("回到底部")
                ToolTip.visible: hovered
                onClicked: messageList.positionViewAtEnd()
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        // ---------- 输入区 ----------
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.largeSpacing
            radius: Kirigami.Units.cornerRadius
            color: Kirigami.Theme.alternateBackgroundColor
            implicitHeight: inputColumn.implicitHeight + Kirigami.Units.smallSpacing * 2

            ColumnLayout {
                id: inputColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                ScrollView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(input.implicitHeight, win.height * 0.3)
                    clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    TextArea {
                        id: input
                        wrapMode: TextArea.Wrap
                        placeholderText: qsTr("给 Goose 发消息…（Enter 发送，Shift+Enter 换行）")
                        selectByMouse: true
                        background: null
                        padding: Kirigami.Units.smallSpacing

                        function accept() {
                            chatStore.send(text)
                            clear()
                        }

                        Keys.onPressed: event => {
                            if ((event.key === Qt.Key_Enter || event.key === Qt.Key_Return)
                                && !(event.modifiers & Qt.ShiftModifier)) {
                                accept()
                                event.accepted = true
                            }
                        }
                    }
                }

                RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    // 示例提示，点一下填进输入框
                    Repeater {
                        model: [qsTr("介绍你自己"), qsTr("写个 Quickshell 小部件"), qsTr("ACP 是什么")]

                        delegate: Kirigami.Chip {
                            required property string modelData
                            text: modelData
                            closable: false
                            checkable: false
                            onClicked: {
                                input.text = modelData
                                input.forceActiveFocus()
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Label {
                        text: qsTr("Enter 发送 · Shift+Enter 换行")
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                        Layout.alignment: Qt.AlignVCenter
                        visible: input.text.length === 0
                    }

                    Button {
                        id: sendButton
                        icon.name: "document-send"
                        text: qsTr("发送")
                        enabled: input.text.trim().length > 0 && !chatStore.busy
                        onClicked: input.accept()
                    }
                }
            }
        }
    }

    // ==================== IPC ====================
    // qs ipc call goose toggle | open | close | send '文本' | clear
    IpcHandler {
        target: "goose"

        function toggle(): void {
            win.open = !win.open
        }
        function open(): void {
            win.open = true
        }
        function close(): void {
            win.open = false
        }
        function send(text: string): void {
            chatStore.send(text)
        }
        function clear(): void {
            chatStore.clear()
        }
    }
}
