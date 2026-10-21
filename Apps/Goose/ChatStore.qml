pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import QtQuick.Controls
import "."

// ============================================================================
// 聊天数据模型（仅 UI 用）。
// 现在是演示数据：send() 把用户消息写进 ListModel，再用两个 Timer
// 模拟"思考 → 逐词流式输出"的助手回复。
//
// 接 ACP（Agent Client Protocol）时只动这一层：
//   send()            -> 往 goose 进程写 session/prompt 的 JSON-RPC
//   进程的 message/*  -> 事件回流时调 updateMessage() / addMessage()
// 上层 UI（GooseWindow / ChatMessage / ThinkBlock）不用改。
// 根元素用 Item 只是图它有默认 data 属性，能挂 ListModel / Timer；
// 它从不参与渲染。
// ============================================================================
Item {
    id: store

    // 消息列表。每条消息的角色（ListElement roles）：
    //   mrole        "user" | "assistant" | "interface"
    //   content      正文（支持 Qt 的 markdown 子集）
    //   thinking     思考块内容（空字符串 = 没有思考块）
    //   thinkingDone 思考块是否完成（未完成时显示"思考中..."转圈）
    //   done         整条消息是否输出完毕
    //   time         发送时间（hh:mm）
    property ListModel messages: messageModel

    // 生成中（用来禁用发送 / 重新生成）
    property bool busy: false

    // 连接状态
    property string connectionStatus: "disconnected"  // disconnected, connecting, connected, error

    // 模型与思考强度（仅 UI 侧状态；接 ACP 时同步到 provider）
    property string currentModel: "custom_internscience"
    property string currentProvider: "custom_internscience"
    property string thinkingEffort: "medium"   // "low" | "medium" | "high"

    readonly property var availableProviders: [
        {id: "custom_internscience", name: "InternScience (Atria-Dawn)"},
        {id: "custom_alitoken_plan", name: "Alibaba Token Plan"},
        {id: "custom_deepseek",      name: "DeepSeek Flash"},
        {id: "custom_doufu",         name: "Doufu GPT-5.6"},
        {id: "custom_alibaba__china",name: "Alibaba China"},
        {id: "zai",                  name: "Z.ai GLM-4.7"},
        {id: "zhipu",                name: "Zhipu GLM-4.7"},
        {id: "github_copilot",       name: "GitHub Copilot"},
        {id: "moonshot",             name: "Moonshot Kimi"},
        {id: "gemini-cli",           name: "Gemini CLI"},
        {id: "google",               name: "Google Gemini"},
        {id: "nvidia",               name: "NVIDIA Nemotron"},
        {id: "alibaba",              name: "Alibaba Qwen"},
        {id: "llama_swap",           name: "Local Llama Swap"}
    ]
    readonly property var availableModels: [
        {id: "gpt-4o",           name: "GPT-4o"},
        {id: "gpt-4o-mini",      name: "GPT-4o mini"},
        {id: "claude-3.5",       name: "Claude 3.5 Sonnet"},
        {id: "local-llama",      name: "本地 Llama 3.1 (Ollama)"},
        {id: "custom_internscience", name: "Atria-Dawn-Preview (InternScience)"}
    ]
    readonly property var effortOptions: [
        {id: "low",    label: qsTr("低"),    icon: "battery-030-charging"},
        {id: "medium", label: qsTr("中等"),  icon: "battery-060-charging"},
        {id: "high",   label: qsTr("高"),    icon: "battery-090-charging"}
    ]

    // ACP 客户端实例
    AcpClient {
        id: acp
        onStatusChanged: (status, msg) => {
            connectionStatus = status
            if (status === "error") {
                addMessage("interface", qsTr("ACP 连接错误: %1").arg(msg))
            } else if (status === "connected") {
                addMessage("interface", qsTr("已连接到 Goose ACP (%1 / %2)").arg(currentProvider, currentModel))
            }
        }
        onAppendStreamingContent: (text) => handleStreamingContent(text)
        onAppendThinkingContent: (text) => handleThinkingContent(text)
        onAppendToolCall: (data) => handleToolCall(data)
    }

    function setModel(modelId) {
        if (currentModel !== modelId) {
            currentModel = modelId
        }
    }
    function setProvider(providerId) {
        if (currentProvider !== providerId) {
            currentProvider = providerId
        }
    }
    function setThinkingEffort(effortId) {
        if (thinkingEffort !== effortId) {
            thinkingEffort = effortId
        }
    }

    ListModel {
        id: messageModel
    }

    // 当前正在流式输出的消息索引
    property int streamingMessageIndex: -1
    property string streamingContent: ""
    property string streamingThinking: ""

    Component.onCompleted: {
        addMessage("interface", qsTr('点击"连接 ACP"按钮开始与 Goose 对话'))
    }

    // ==================== 对外操作 ====================
    function send(text) {
        const body = String(text ?? "").trim()
        if (body.length === 0 || store.busy)
            return

        if (connectionStatus !== "connected") {
            addMessage("interface", qsTr("未连接到 ACP，正在连接..."))
            connectACP()
            return
        }

        addMessage("user", body)
        sendToACP(body)
    }

    function connectACP() {
        if (connectionStatus === "connecting" || connectionStatus === "connected") return
        connectionStatus = "connecting"
        acp.start(currentProvider, currentModel)
    }

    function disconnectACP() {
        acp.stop()
        connectionStatus = "disconnected"
        streamingMessageIndex = -1
    }

    function sendToACP(text) {
        store.busy = true
        streamingMessageIndex = addMessage("assistant", "", {
            "thinking": "",
            "thinkingDone": false,
            "done": false
        })
        streamingContent = ""
        streamingThinking = ""

        acp.sendPrompt(text).then(() => {
        }).catch((err) => {
            console.error("Send prompt failed:", err)
            updateMessage(streamingMessageIndex, {
                "content": qsTr("发送失败: %1").arg(err.message),
                "done": true,
                "thinkingDone": true
            })
            store.busy = false
            streamingMessageIndex = -1
        })
    }

    function clear() {
        acp.cancel()
        acp.stop()
        connectionStatus = "disconnected"
        streamingMessageIndex = -1
        streamingContent = ""
        streamingThinking = ""
        messageModel.clear()
        addMessage("interface", qsTr('点击"连接 ACP"按钮开始与 Goose 对话'))
    }

    function removeMessage(index) {
        if (index < 0 || index >= messageModel.count)
            return
        messageModel.remove(index, 1)
    }

    function copyMessage(index) {
        if (index < 0 || index >= messageModel.count)
            return
        Quickshell.clipboardText = messageModel.get(index).content
    }

    function regenerate(index) {
        if (store.busy)
            return
        let i = Math.min(index, messageModel.count - 1)
        while (i >= 0 && messageModel.get(i).mrole !== "user")
            i--
        if (i < 0)
            return
        const prompt = messageModel.get(i).content
        messageModel.remove(i + 1, messageModel.count - i - 1)
        sendToACP(prompt)
    }

    // ==================== 底层写操作 ====================
    function stamp() {
        return Qt.formatTime(new Date(), "hh:mm")
    }

    function addMessage(role, content, opts) {
        const o = opts ?? {}
        messageModel.append({
            "mrole": role,
            "content": String(content),
            "thinking": o.thinking ?? "",
            "thinkingDone": o.thinkingDone ?? true,
            "done": o.done ?? true,
            "time": stamp()
        })
        return messageModel.count - 1
    }

    function updateMessage(index, patch) {
        if (index < 0 || index >= messageModel.count)
            return
        messageModel.set(index, patch)
    }

    // ==================== 流式内容处理 ====================
    function handleStreamingContent(text) {
        if (streamingMessageIndex < 0) return
        streamingContent += text
        updateMessage(streamingMessageIndex, {
            "content": streamingContent
        })
    }

    function handleThinkingContent(text) {
        if (streamingMessageIndex < 0) return
        streamingThinking += text
        updateMessage(streamingMessageIndex, {
            "thinking": streamingThinking,
            "thinkingDone": false
        })
    }

    function handleToolCall(data) {
        console.log("Tool call:", data)
    }

    Timer {
        id: finishCheckTimer
        interval: 2000
        repeat: true
        running: store.busy
        onTriggered: {
            if (streamingMessageIndex >= 0) {
                const msg = messageModel.get(streamingMessageIndex)
            }
        }
    }

    // ==================== 演示数据（ACP 未连接时使用） ====================
    readonly property var cannedReplies: [
        qsTr("你好！我是 **Goose**，一个跑在 Quickshell 里的 AI 助手。\n\n现在处于**演示模式**——界面已经长好，但还没接 ACP 提供者，所以这段话来自 `Apps/Goose/ChatStore.qml` 里的模拟数据。\n\n几处结构说明：\n\n- 消息卡片：`Kirigami.AbstractCard`（`ChatMessage.qml`）\n- 思考块：`ThinkBlock.qml`，可折叠\n- 状态条 / 输入区 / IPC 都在 `GooseWindow.qml`\n\n```qml\n// 接 ACP 后 send() 大概长这样：\n// provider.write(JSON.stringify(jsonrpc))\n```"),
        qsTr("写 Quickshell 小部件的套路：\n\n1. 在 `Modules/` 下建个 `.qml`，根元素用 `Item` / `Rectangle`\n2. 用 `Layout` 排内容，别用绝对坐标\n3. 想做全局开关就挂到 `Config/WidgetState.qml`\n\n```qml\nimport QtQuick\nimport Quickshell\n\nPanelWindow {\n    anchors { top: true; left: true; right: true }\n    height: 32\n    Text { text: \"hello goose\" }\n}\n```\n\n要点：`PanelWindow` 是 Wayland 层表面，锚定和高度都交给合成器管。"),
        qsTr("**ACP（Agent Client Protocol）** 是聊天式客户端和 agent 之间通信的 JSON-RPC 协议。\n\n在本项目里的分工：\n\n- **提供者（provider）**：跑 goose 进程，收 prompt、回流 stream / finish 事件\n- **这个 UI**：只是视图，把用户输入转成 `session/prompt`，把回流事件渲染成消息卡片\n\n`ChatStore` 已经按这个形状留好了 `send()` / `addMessage()` / `updateMessage()`，接入时替换掉 `mockReply()` 就行。"),
        qsTr("收到。这条回复用来验证长文本在卡片里的折行与滚动：\n\n> 消息卡片用 `Kirigami.AbstractCard`，`header` 放角色徽章和操作按钮，`contentItem` 放思考块和正文。\n\n- Enter 发送，Shift+Enter 换行\n- 列表没贴底时右下角有\"回到底部\"按钮\n- 顶部是状态条，底部是输入区和示例提示\n\n方便的话说说接下来想先接哪部分。")
    ]

    function mockReply(prompt) {
        store.busy = true
        const reply = store.cannedReplies[Math.floor(Math.random() * store.cannedReplies.length)]
        const idx = addMessage("assistant", "", {
            "thinking": qsTr("用户问的是：%1\n\n这是演示用的思考块。接入 ACP 后，这里会是模型真正的推理过程，完成后可折叠。").arg(prompt.slice(0, 80)),
            "thinkingDone": false,
            "done": false
        })
        thinkTimer.targetIndex = idx
        thinkTimer.reply = reply
        thinkTimer.start()
    }

    Timer {
        id: thinkTimer
        property int targetIndex: -1
        property string reply: ""
        interval: 900
        repeat: false
        onTriggered: {
            store.updateMessage(targetIndex, { "thinkingDone": true })
            streamTimer.targetIndex = targetIndex
            streamTimer.reply = reply
            streamTimer.words = reply.match(/\S+|\s+/g) ?? []
            streamTimer.cursor = 0
            streamTimer.acc = ""
            streamTimer.start()
        }
    }

    Timer {
        id: streamTimer
        property int targetIndex: -1
        property string reply: ""
        property var words: []
        property int cursor: 0
        property string acc: ""
        interval: 60
        repeat: true
        onTriggered: {
            let steps = 0
            while (cursor < words.length && steps < 2) {
                acc += words[cursor]
                cursor++
                steps++
            }
            if (cursor >= words.length) {
                stop()
                store.updateMessage(targetIndex, { "content": reply, "done": true })
                store.busy = false
            } else {
                store.updateMessage(targetIndex, { "content": acc })
            }
        }
    }
}