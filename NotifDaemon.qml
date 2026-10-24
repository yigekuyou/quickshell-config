// 通知服务（org.freedesktop.Notifications）独立进程。
//
// 启动方式：不要手写，由主进程的 NotificationManager 单例用
//   Process.startDetached() 拉起（quickshell 原生能力：qs 重载 / 退出都
//   不杀 detached 子进程）。历史上这里由 scripts/notifd-watch.sh 看护，
//   现在看护逻辑全部回到 QML，脚本已删除。
//
// 为什么要单独一个进程：
//   org.freedesktop.Notifications 是独占名，而一条带图片的 Notify 就有一两百 KB。
//   以前 server 和顶栏 / 全局菜单 / SNI 共用主进程的同一条 session bus 连接，
//   通知一多就把这条连接的 UID 字节配额撑爆，dbus-broker 直接把整条连接踢掉，
//   于是整个顶栏、SNI、全局菜单一起 "Not connected to D-Bus server"。
//   拆出来以后洪水最多打死这个进程，NotificationManager 几秒后把它拉起来。
//
// 自我了断的两种情况（都是「退出让主进程重拉」）：
//   1. 名字不在本进程手里（被人占着 / 抢不到）—— 启动竞争中的落败者；
//   2. 名字谁都没有 —— 连接已被 dbus-broker 掐掉、本进程成了僵尸
//      （进程活着、socket 还在，只是收不到 Notify 了）。
//
// 这个进程不画任何东西：它只负责收通知、把数据序列化后推给主进程（unix socket），
// 并接受主进程发来的 dismiss / expire / invoke 命令。

import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

ShellRoot {
    id: root

    // 与主进程之间的 unix socket。用 socket 不用 qs ipc：
    // ipc call 每次要 fork 一个完整的 qs 进程，洪水时开销比通知本身还大
    readonly property string socketPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-notifd.sock"

    // ---- 可调参数 ----
    // 主进程最多留 40 条；这里多留一些，好在主进程重载时补发
    readonly property int maxTracked: 60
    // 正文可能有几 MB，跨进程只送用得上的部分
    readonly property int bodyLimit: 2048
    readonly property int summaryLimit: 512

    // 待发送的操作，合并成一批再发：每条通知都 fork 一个 qs 太浪费
    property var outbox: []

    // id → 到达时间。不要每次序列化都现取 Date.now()：
    // hello 补发时会把时间刷成"现在"，历史里的时间戳就全乱了
    property var bornAt: ({})

    // ==================== 通知服务器 ====================
    NotificationServer {
        id: server
        // 能力声明与拆进程之前保持一致
        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: true
        imageSupported: true
        inlineReplySupported: false
        persistenceSupported: false
        // 本进程自己重载时保住名字
        keepOnReload: true

        onNotification: function (notification) {
            if (!notification)
                return;

            // tracked：留在 trackedNotifications 里，主进程才能按 id 找回来操作
            notification.tracked = true;

            if (root.bornAt[notification.id] === undefined) {
                const born = root.bornAt;
                born[notification.id] = Date.now();
                root.bornAt = born;
            }

            // 应用自己撤销 / 用户从别处关掉 / 被 dismiss()：通知主进程从历史里摘掉
            notification.closed.connect(function (reason) {
                const born = root.bornAt;
                delete born[notification.id];
                root.bornAt = born;
                root.push({
                    op: "closed",
                    id: notification.id
                });
            });

            root.push({
                op: "add",
                n: root.serialize(notification)
            });
            root.trimTracked();
        }
    }

    // ==================== 序列化 / 发送 ====================
    // 主进程拿到的是普通 JS 对象，不是 Notification（跨进程传不了 QObject）
    function serialize(n) {
        const actions = [];
        const list = n.actions || [];
        for (let i = 0; i < list.length; i++) {
            actions.push({
                identifier: String(list[i].identifier || ""),
                text: String(list[i].text || "")
            });
        }

        // image 可能是本进程内部的 image provider（image://...），主进程解析不了；
        // 只有真路径/文件 URL 才送过去，其余留空，UI 回落到 appIcon
        let image = String(n.image || "");
        if (image !== "" && image.indexOf("/") !== 0 && image.indexOf("file:") !== 0)
            image = "";

        return {
            id: n.id,
            appName: String(n.appName || "").substring(0, 256),
            appIcon: String(n.appIcon || "").substring(0, 512),
            image: image.substring(0, 1024),
            summary: String(n.summary || "").substring(0, root.summaryLimit),
            body: String(n.body || "").substring(0, root.bodyLimit),
            urgency: Number(n.urgency),
            resident: !!n.resident,
            expireTimeout: Number(n.expireTimeout),
            // 到达时间：主进程用它排序、显示、按时间注销。
            // 用 bornAt 里记的原始到达时间，hello 补发才不会把时间刷成"现在"
            timestamp: Number(root.bornAt[n.id]) || Date.now(),
            actions: actions
        };
    }

    // ==================== 与主进程的连接 ====================
    // 每个连上来的主进程一个 Socket。正常只有一个；主进程重载的瞬间可能短暂重叠
    property var conns: []

    function addConn(c) {
        const next = root.conns.slice();
        next.push(c);
        root.conns = next;
        // 连上就先把全量塞过去。主进程那边连上也会发 hello，两条路都走一遍
        // 是故意的：重连瞬间到达的通知会落在"它还没挂上 conns"的空档里，
        // 只靠 hello 的话这个窗口内的通知就丢了
        root.sendSnapshot(c);
    }

    function dropConn(c) {
        root.conns = root.conns.filter(x => x !== c);
    }

    // 推一条事件：{op:"add", n:{...}} / {op:"closed", id:1} / {op:"hello", list:[...]}
    function push(evt) {
        if (root.conns.length === 0)
            return;
        const line = JSON.stringify(evt) + "\n";
        for (let i = 0; i < root.conns.length; i++) {
            const c = root.conns[i];
            if (c && c.connected)
                c.write(line);
        }
    }

    // ==================== socket 文件清理 ====================
    // SocketServer 绑定：本进程正常退出时会自己删掉 socket 文件，但被
    // kill -9 / OOM 打死会留下空文件，下一次绑不上（QLocalServer 见到
    // 已存在的路径直接 EADDRINUSE）。先 rm 再绑。
    // socketReady = false 卡住绑定；rm 极快，正常 50ms 内 onExited。
    // 万一 rm 进程没起来（理论上不会），后面的兜底 Timer 也会放行。
    property bool socketReady: false

    Process {
        id: sockClean
        running: true
        command: ["rm", "-f", root.socketPath]
        onExited: root.socketReady = true
    }

    Timer {
        // rm 万卡住的兜底：1s 后无条件放行绑定
        interval: 1000
        repeat: false
        running: true
        onTriggered: root.socketReady = true
    }

    SocketServer {
        path: root.socketPath
        active: root.socketReady
        handler: Component {
            Socket {
                id: client
                parser: SplitParser {
                    onRead: line => root.onClientLine(line)
                }
                Component.onCompleted: root.addConn(client)
                onConnectionStateChanged: {
                    if (client.connected)
                        return;
                    root.dropConn(client);
                    // 文档写法：connected = false 会关闭并删除该 socket；
                    // destroy() 会报 "Invalid attempt to destroy() an indestructible object"
                    client.connected = false;
                }
            }
        }
    }

    // 把还在跟踪的通知整份补发（主进程启动 / 重载 / 重连时）
    function sendSnapshot(only) {
        const list = [];
        if (server.trackedNotifications) {
            const values = [...server.trackedNotifications.values];
            for (let i = 0; i < values.length; i++) {
                if (values[i])
                    list.push(root.serialize(values[i]));
            }
        }
        const evt = {
            op: "hello",
            list: list
        };
        if (only) {
            if (only.connected)
                only.write(JSON.stringify(evt) + "\n");
            return;
        }
        root.push(evt);
    }

    // 主进程发来的命令，每行一个 JSON
    function onClientLine(line) {
        let msg = null;
        try {
            msg = JSON.parse(line);
        } catch (e) {
            console.warn("notifd: 无法解析主进程的命令:", e);
            return;
        }
        if (!msg || !msg.cmd)
            return;

        if (msg.cmd === "hello") {
            root.sendSnapshot();
        } else if (msg.cmd === "dismiss") {
            root.withNotification(Number(msg.id), n => n.dismiss());
        } else if (msg.cmd === "expire") {
            root.withNotification(Number(msg.id), n => n.expire());
        } else if (msg.cmd === "invoke") {
            const action = String(msg.action);
            root.withNotification(Number(msg.id), n => {
                const list = n.actions || [];
                for (let i = 0; i < list.length; i++) {
                    if (String(list[i].identifier) === action) {
                        list[i].invoke();
                        return;
                    }
                }
            });
        } else if (msg.cmd === "dismissAll") {
            if (!server.trackedNotifications)
                return;
            const values = [...server.trackedNotifications.values];
            for (let i = 0; i < values.length; i++) {
                if (values[i])
                    values[i].dismiss();
            }
        }
    }

    // ==================== 跟踪列表上限 ====================
    // trackedNotifications 不会自己清理；只置 tracked=false 摘掉，不给应用发 NotificationClosed
    function trimTracked() {
        if (!server.trackedNotifications)
            return;
        const values = [...server.trackedNotifications.values];
        let overflow = values.length - root.maxTracked;
        for (let i = 0; i < values.length && overflow > 0; i++) {
            const n = values[i];
            if (!n)
                continue;
            n.tracked = false;
            overflow--;
        }
    }

    function withNotification(id, fn) {
        if (!server.trackedNotifications)
            return;
        const values = [...server.trackedNotifications.values];
        for (let i = 0; i < values.length; i++) {
            const n = values[i];
            if (n && n.id === id) {
                fn(n);
                return;
            }
        }
    }

    // ==================== 名字所有权自检 ====================
    // 独占名抢不到时（典型场景：上一代主进程里的 server 还没释放名字），
    // 本进程会变成一个"活着但不收通知"的空壳。每 20s 查一次名字在谁手里：
    //   - 在别人手里：启动竞争的落败者，退出让主进程重拉；
    //   - 谁都没有：总线连接已被 dbus-broker 掐了（通知洪水的后果），本进程
    //     成了僵尸 —— 进程活着、socket 还连着，主进程那边看不出它死了，
    //     必须自己退出，主进程的重拉逻辑才有机会动手；
    //   - busctl 自己都连不上总线：查不了就不管，别把自己弄死。
    Process {
        id: ownerCheck
        command: ["busctl", "--user", "call", "org.freedesktop.DBus",
            "/org/freedesktop/DBus", "org.freedesktop.DBus",
            "GetConnectionUnixProcessID", "s", "org.freedesktop.Notifications"]
        stdout: StdioCollector {
            id: ownerOut
        }
        stderr: StdioCollector {
            id: ownerErr
        }
        onExited: function (exitCode) {
            if (exitCode === 0) {
                const m = String(ownerOut.text || "").match(/(\d+)\s*$/);
                if (m && Number(m[1]) !== Quickshell.processId) {
                    console.warn("notifd: 通知服务名不在本进程手里，退出等重启");
                    Qt.quit();
                }
                return;
            }
            if (/NameHasNoOwner|no such name|not owned/i.test(String(ownerErr.text || ""))) {
                console.warn("notifd: 通知服务名已无主（连接被掐），退出等重启");
                Qt.quit();
            }
        }
    }

    Timer {
        interval: 20000
        repeat: true
        running: true
        onTriggered: ownerCheck.exec(ownerCheck.command)
    }

}
