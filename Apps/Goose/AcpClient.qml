pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// ============================================================================
// ACP (Agent Client Protocol) 客户端实现 - 通过 stdio 与 goose acp 进程通信
// ============================================================================
Item {
    id: acpClient

    property bool connected: false
    property string sessionId: ""
    property int requestId: 0
    property var pendingRequests: ({})
    property var acpProcess: null
    property var sessionNewTimer: null

    signal statusChanged(string status, string message)
    signal appendStreamingContent(string text)
    signal appendThinkingContent(string text)
    signal appendToolCall(var data)

    // 启动 goose acp 进程
    function start(provider, model) {
        if (acpProcess) return

        const env = [
            `GOOSE_PROVIDER=${provider}`,
            `GOOSE_MODEL=${model}`,
            `GOOSE_TELEMETRY_ENABLED=false`,
            `GOOSE_DISABLE_KEYRING=1`,
            `GOOSE_MODE=auto`
        ]

        acpProcess = Quickshell.spawnProcess("goose", ["acp"], {env: env})

        acpProcess.onStdout = (line) => {
            handleMessage(line)
        }
        acpProcess.onStderr = (line) => {
            console.warn("ACP stderr:", line)
        }
        acpProcess.onFinished = (code) => {
            console.log("ACP process finished with code:", code)
            connected = false
            sessionId = ""
        }

        // 发送 initialize
        sendRequest("initialize", {
            protocolVersion: 1,
            capabilities: {}
        }).then((result) => {
            console.log("ACP initialized:", result)
            connected = true
            
            // 创建会话 - 添加超时保护
            const sessionPromise = sendRequest("session/new", {
                cwd: "/home/light",
                mcpServers: {}
            })
            
            // 30秒超时 - goose 1.55.0 有已知 bug 会卡在 session/new
            const timeoutPromise = new Promise((_, reject) => {
                sessionNewTimer = setTimeout(() => {
                    reject(new Error("session/new 超时 (goose 1.55.0 已知 bug，正在重试...)"))
                }, 30000)
            })
            
            return Promise.race([sessionPromise, timeoutPromise])
        }).then((result) => {
            if (sessionNewTimer) {
                clearTimeout(sessionNewTimer)
                sessionNewTimer = null
            }
            sessionId = result.sessionId
            console.log("ACP session created:", sessionId)
            statusChanged("connected", "")
        }).catch((err) => {
            if (sessionNewTimer) {
                clearTimeout(sessionNewTimer)
                sessionNewTimer = null
            }
            console.error("ACP connection failed:", err)
            // 连接失败时仍标记为 connected，允许用户手动重试
            connected = true
            sessionId = "pending"
            statusChanged("error", err.message)
        })
    }

    function stop() {
        if (sessionNewTimer) {
            clearTimeout(sessionNewTimer)
            sessionNewTimer = null
        }
        if (acpProcess) {
            acpProcess.kill()
            acpProcess = null
        }
        connected = false
        sessionId = ""
        pendingRequests = {}
    }

    function sendRequest(method, params) {
        return new Promise((resolve, reject) => {
            if (!acpProcess) {
                reject(new Error("ACP process not started"))
                return
            }
            const id = ++requestId
            pendingRequests[id] = {resolve, reject, method}
            const msg = JSON.stringify({
                jsonrpc: "2.0",
                id: id,
                method: method,
                params: params
            })
            acpProcess.write(msg + "\n")
        })
    }

    function sendNotification(method, params) {
        if (!acpProcess) return
        const msg = JSON.stringify({
            jsonrpc: "2.0",
            method: method,
            params: params
        })
        acpProcess.write(msg + "\n")
    }

    function handleMessage(line) {
        try {
            const msg = JSON.parse(line)
            if (msg.id && pendingRequests[msg.id]) {
                const req = pendingRequests[msg.id]
                delete pendingRequests[msg.id]
                if (msg.error) {
                    req.reject(new Error(msg.error.message))
                } else {
                    req.resolve(msg.result)
                }
            } else if (msg.method) {
                handleNotification(msg.method, msg.params)
            }
        } catch (e) {
            console.error("Failed to parse ACP message:", line, e)
        }
    }

    function handleNotification(method, params) {
        console.log("ACP notification:", method, params)
        switch (method) {
            case "session/update":
                handleSessionUpdate(params)
                break
            case "goose/unstable/session/update":
                handleGooseSessionUpdate(params)
                break
        }
    }

    function handleSessionUpdate(params) {
        if (params.update && params.update.type === "agent_message_chunk") {
            const chunk = params.update
            if (chunk.content) {
                appendStreamingContent(chunk.content)
            }
        }
    }

    function handleGooseSessionUpdate(params) {
        if (params.update) {
            const update = params.update
            if (update.kind === "text" && update.text) {
                appendStreamingContent(update.text)
            } else if (update.kind === "thinking" && update.text) {
                appendThinkingContent(update.text)
            } else if (update.kind === "tool_call") {
                appendToolCall(update)
            }
        }
    }

    // 发送用户消息
    function sendPrompt(text) {
        if (!connected || !sessionId) return Promise.reject(new Error("Not connected"))
        if (sessionId === "pending") {
            return Promise.reject(new Error("会话尚未创建完成，请稍候或点击重新连接"))
        }
        return sendRequest("session/prompt", {
            sessionId: sessionId,
            prompt: [{type: "text", text: text}]
        })
    }

    // 取消当前生成
    function cancel() {
        if (!connected || !sessionId) return
        sendRequest("session/cancel", {sessionId: sessionId})
    }

    // 重新尝试创建会话
    function retrySession() {
        if (!connected || !acpProcess) return Promise.reject(new Error("Not connected"))
        
        if (sessionNewTimer) {
            clearTimeout(sessionNewTimer)
            sessionNewTimer = null
        }
        
        statusChanged("connecting", "正在重试创建会话...")
        
        const sessionPromise = sendRequest("session/new", {
            cwd: "/home/light",
            mcpServers: {}
        })
        
        const timeoutPromise = new Promise((_, reject) => {
            sessionNewTimer = setTimeout(() => {
                reject(new Error("session/new 超时 (goose 1.55.0 已知 bug)"))
            }, 30000)
        })
        
        return Promise.race([sessionPromise, timeoutPromise]).then((result) => {
            if (sessionNewTimer) {
                clearTimeout(sessionNewTimer)
                sessionNewTimer = null
            }
            sessionId = result.sessionId
            console.log("ACP session created:", sessionId)
            statusChanged("connected", "")
        }).catch((err) => {
            if (sessionNewTimer) {
                clearTimeout(sessionNewTimer)
                sessionNewTimer = null
            }
            console.error("Retry session failed:", err)
            sessionId = "pending"
            statusChanged("error", err.message)
            throw err
        })
    }
}