pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.Config

// 通知中心 / 弹窗的唯一数据源。
//
// 架构：NotificationServer 不在本进程里，跑在独立的 qs 进程
// （NotifDaemon.qml）。由本单例用 Process.startDetached() 拉起并看护
// （quickshell 原生的 detached：qs 重载 / 退出都不杀子进程，替代历史上的
// scripts/notifd-watch.sh）。

//
// 为什么拆：
//   org.freedesktop.Notifications 是独占名，一条带图片的 Notify 就有一两百 KB。
//   以前 server 和顶栏 / 全局菜单 / SNI 共用主进程的同一条 session bus 连接，
//   通知一多就把这条连接的 UID 字节配额撑爆，dbus-broker 直接踢掉整条连接，
//   于是顶栏、SNI、全局菜单一起 "Not connected to D-Bus server"。拆出去以后
//   洪水最多打死守护进程，主进程的总线连接不受牵连。
//
// 本文件只做三件事：收守护进程推来的数据、排队弹窗、维护历史（带时间戳）。
// 历史里的元素是普通 JS 对象，不是 Notification，字段见 makeItem()。
Singleton {
    id: root

    // ==================== 可调参数 ====================
    readonly property int maxPopups: 3          // 屏幕右上角同时最多显示几张
    readonly property int defaultTimeout: 6000  // 客户端传 -1 时的停留时长
    readonly property int maxTimeout: 20000     // 客户端要求再久也最多留这么久
    readonly property int maxHistory: 40        // 通知中心最多留几条

    // 历史消息的保留时长：带时间戳进来的通知超过这个时间就从通知中心注销掉。
    // 设 0 表示只按条数限制、不按时间注销。
    readonly property int historyRetentionMs: 30 * 60 * 1000

    property bool dnd: false

    // 历史（新的在前）。元素带 dismiss() / expire() / actions[].invoke()，
    // UI 侧用法和以前拿 Notification 时完全一致。
    property var items: []

    // 屏幕右上角的弹窗队列
    property var popups: []
    readonly property bool hasPopups: popups.length > 0

    readonly property int count: items.length

    // 通知中心用的排序快照。
    //
    // 面板里每条通知是一整棵 FormCard，模型一变 Repeater 会全量重建；
    // 面板关着时快照就是空的（零开销），开着时把短时间内的多次变化合并成一次刷新。
    property var snapshot: []
    readonly property int snapshotInterval: 120

    // ==================== 数据入口 ====================
    // 一条消息就是一批操作：{ ops: [{op:"add", n:{...}}, {op:"closed", id:1}] }
    // silent=true 时不弹窗（重连后补发历史用）
    function ingest(msg, silent) {
        if (!msg || !msg.ops)
            return;

        root.daemonUp = true;

        let history = root.items;
        let popups = root.popups;
        const fresh = [];

        for (let i = 0; i < msg.ops.length; i++) {
            const op = msg.ops[i];
            if (!op)
                continue;

            if (op.op === "add") {
                const item = root.makeItem(op.n || {});
                history = root.upsert(history, item);
                popups = root.replaceIn(popups, item);
                fresh.push(item);
            } else if (op.op === "closed") {
                const id = Number(op.id);
                history = history.filter(h => h.id !== id);
                popups = popups.filter(p => p.id !== id);
            }
        }

        root.items = root.trimByCount(history);
        root.popups = popups;

        // 免打扰 / 面板开着 / 补发历史的时候不弹：通知只进历史
        if (!silent && !root.dnd && !WidgetState.notifOpen) {
            for (let i = 0; i < fresh.length; i++)
                root.addPopup(fresh[i]);
        }

        if (WidgetState.notifOpen)
            snapshotTimer.restart();
    }

    // 把一条原始数据包成一个"像 Notification 一样能用"的对象
    function makeItem(d) {
        const item = {
            id: Number(d.id) || 0,
            appName: d.appName || "",
            appIcon: d.appIcon || "",
            image: d.image || "",
            summary: d.summary || "",
            body: d.body || "",
            urgency: d.urgency === undefined ? NotificationUrgency.Normal : Number(d.urgency),
            resident: !!d.resident,
            expireTimeout: d.expireTimeout === undefined ? -1 : Number(d.expireTimeout),
            timestamp: Number(d.timestamp) || Date.now(),
            actions: []
        };

        const actions = d.actions || [];
        for (let i = 0; i < actions.length; i++) {
            const a = actions[i] || {};
            item.actions.push({
                identifier: String(a.identifier || ""),
                text: String(a.text || ""),
                invoke: function () {
                    root.invokeAction(item.id, this.identifier);
                }
            });
        }

        item.dismiss = function () {
            root.dismiss(item);
        };
        item.expire = function () {
            root.expire(item);
        };
        return item;
    }

    function upsert(list, item) {
        const next = list.slice();
        for (let i = 0; i < next.length; i++) {
            if (next[i].id === item.id) {
                next[i] = item;   // replaces_id 更新：原地换掉，位置不动
                return next;
            }
        }
        next.unshift(item);       // 新的在最前面
        return next;
    }

    function replaceIn(list, item) {
        const next = list.slice();
        for (let i = 0; i < next.length; i++) {
            if (next[i].id === item.id) {
                next[i] = item;
                return next;
            }
        }
        return list;
    }

    function trimByCount(list) {
        if (list.length <= root.maxHistory)
            return list;
        return list.slice(0, root.maxHistory);
    }

    // ==================== 快照 ====================
    function refreshSnapshot() {
        const list = root.items.slice();
        list.sort((a, b) => {
            const ac = a.urgency === NotificationUrgency.Critical;
            const bc = b.urgency === NotificationUrgency.Critical;
            if (ac !== bc)
                return ac ? -1 : 1;
            if (b.timestamp !== a.timestamp)
                return b.timestamp - a.timestamp;
            return b.id - a.id;   // 同一毫秒到达时用 id 兜底，越大越新
        });
        root.snapshot = list;
    }

    // 合并刷新：150 条通知在 1 秒里涌进来也只重建一次列表
    Timer {
        id: snapshotTimer
        interval: root.snapshotInterval
        repeat: false
        onTriggered: {
            if (WidgetState.notifOpen)
                root.refreshSnapshot();
        }
    }

    // ==================== 按时间注销 ====================
    // 每条历史都带 timestamp：超过 historyRetentionMs 的从通知中心摘掉。
    // 只做本地摘除（不向应用发 NotificationClosed），免得应用以为用户看过了；
    // 守护进程那边另有一套按条数的上限，不会无限增长。
    Timer {
        interval: 30000
        repeat: true
        running: root.historyRetentionMs > 0 && root.items.length > 0
        onTriggered: root.trimByAge()
    }

    function trimByAge() {
        if (root.historyRetentionMs <= 0 || root.items.length === 0)
            return;
        const cutoff = Date.now() - root.historyRetentionMs;
        const kept = root.items.filter(i => i.timestamp >= cutoff);
        if (kept.length === root.items.length)
            return;

        const dropped = root.items.filter(i => i.timestamp < cutoff).map(i => i.id);
        root.items = kept;
        // 正在弹出的那几条如果被时间注销了，一起收掉
        root.popups = root.popups.filter(p => dropped.indexOf(p.id) < 0);
        if (WidgetState.notifOpen)
            snapshotTimer.restart();

        // 同步告诉守护进程：注销掉，别只在本进程里装作没有。
        // 否则它还在 trackedNotifications 里，下次 hello 补发会把这些
        // "已经过期"的通知又灌回历史。
        for (let i = 0; i < dropped.length; i++)
            root.daemonCmd({ cmd: "dismiss", id: dropped[i] });
    }

    // "HH:mm"，不是今天的带上月/日
    function timeLabel(ts) {
        const t = Number(ts) || 0;
        if (t <= 0)
            return "";
        const d = new Date(t);
        const now = new Date();
        const hh = String(d.getHours()).padStart(2, "0");
        const mm = String(d.getMinutes()).padStart(2, "0");
        if (d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth()
                && d.getDate() === now.getDate())
            return hh + ":" + mm;
        return (d.getMonth() + 1) + "/" + d.getDate() + " " + hh + ":" + mm;
    }

    // ==================== 弹窗队列 ====================
    function isShowing(n) {
        if (!n)
            return false;
        for (let i = 0; i < root.popups.length; i++) {
            if (root.popups[i].id === n.id)
                return true;
        }
        return false;
    }

    function addPopup(n) {
        if (!n)
            return;
        // 同一个通知被 replaces_id 更新时不要叠两张
        const next = root.popups.filter(p => p.id !== n.id);
        next.unshift(n);
        // 超出上限的从队尾丢弃（仍然留在历史里，不会丢）
        while (next.length > root.maxPopups)
            next.pop();
        root.popups = next;
    }

    function removePopup(n) {
        if (!n)
            return;
        const next = root.popups.filter(p => p.id !== n.id);
        if (next.length !== root.popups.length)
            root.popups = next;
    }

    function clearPopups() {
        if (root.popups.length > 0)
            root.popups = [];
    }

    // ==================== 与守护进程的连接 ====================
    // unix socket，不用 qs ipc：ipc call 每次都要 fork 一个完整的 qs 进程，
    // 洪水时这点开销比通知本身还大。socket 就是一次 write。
    readonly property string socketPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-notifd.sock"
    property bool daemonUp: false

    function daemonCmd(obj) {
        if (!link.connected)
            return;
        link.write(JSON.stringify(obj) + "\n");
        link.flush();
    }

    Socket {
        id: link
        path: root.socketPath
        connected: true
        parser: SplitParser {
            onRead: line => root.onDaemonLine(line)
        }
        onConnectionStateChanged: {
            root.daemonUp = link.connected;
            if (link.connected) {
                root.spawnFails = 0; // 连上归零，下次故障从头计时
                // 连上（含刚拉起的守护进程）就要一份全量
                root.daemonCmd({
                    cmd: "hello"
                });
            }
        }
        onError: root.daemonUp = false
    }

    // 守护进程重启后自己重连。
    // 不能只靠 connectionStateChanged：守护进程没起来时是 ServerNotFound、
    // 重启时是 PeerClosed，这两种情况下 Quickshell 的 Socket 不会自己再拨，
    // 状态也可能一直是 Unconnected（也就不会有状态变化信号）。所以轮询重拨。
    // 拨不通超过节流窗口就再拉一次（冷启动预热 3s；连不上 5s 起步、
    // 连续失败逐级退避到 30s）：守护进程被 kill -9 / 被总线洪水打死后，
    // 这里是唯一的复活入口。
    property real nextSpawnAllowed: 0
    property int spawnFails: 0

    Process {
        id: daemonSpawn
        running: false
        command: ["qs", "-p", Quickshell.shellDir + "/NotifDaemon.qml"]
    }

    function spawnDaemon() {
        console.log("notif: 守护进程不可达，重新拉起");
        daemonSpawn.startDetached();
        root.spawnFails += 1;
        const delay = root.spawnFails <= 1 ? 5000 : root.spawnFails <= 3 ? 10000 : 30000;
        root.nextSpawnAllowed = Date.now() + delay;
    }

    Component.onCompleted: {
        // 预热 3s：重载场景下老守护进程可能还在服务，
        // 先让 Socket 有机会连上再决定要不要拉新的
        root.nextSpawnAllowed = Date.now() + 3000;
    }

    Timer {
        interval: 2000
        repeat: true
        running: !root.daemonUp
        onTriggered: {
            link.connected = false;
            link.connected = true;
            if (!root.daemonUp && Date.now() > root.nextSpawnAllowed)
                root.spawnDaemon();
        }
    }

    function onDaemonLine(line) {
        let msg = null;
        try {
            msg = JSON.parse(line);
        } catch (e) {
            console.warn("notif: 无法解析守护进程的数据:", e);
            return;
        }
        if (!msg)
            return;
        if (msg.op === "hello") {
            // 全量补发：静默并入（不弹窗），否则每次重连旧通知都再弹一遍
            const list = msg.list || [];
            root.ingest({
                ops: list.map(n => ({
                        op: "add",
                        n: n
                    }))
            }, true);
            return;
        }
        root.ingest({
            ops: [msg]
        });
    }

    function invokeAction(id, action) {
        root.daemonCmd({ cmd: "invoke", id: id, action: action });
    }

    function dismiss(n) {
        if (!n)
            return;
        root.removePopup(n);
        root.items = root.items.filter(i => i.id !== n.id);
        if (WidgetState.notifOpen)
            snapshotTimer.restart();
        root.daemonCmd({ cmd: "dismiss", id: n.id });
    }

    // 超时自动消失：语义上是 Expired 而不是用户主动关闭
    function expire(n) {
        if (!n)
            return;
        root.removePopup(n);
        root.items = root.items.filter(i => i.id !== n.id);
        if (WidgetState.notifOpen)
            snapshotTimer.restart();
        root.daemonCmd({ cmd: "expire", id: n.id });
    }

    function dismissAll() {
        root.clearPopups();
        if (root.items.length > 0) {
            root.items = [];
            if (WidgetState.notifOpen)
                snapshotTimer.restart();
        }
        root.daemonCmd({ cmd: "dismissAll" });
    }

    function toggleDnd() {
        root.dnd = !root.dnd;
    }

    onDndChanged: {
        if (root.dnd)
            root.clearPopups();
    }

    // 通知中心一打开就把右上角的弹窗收掉，否则两摞东西叠在同一个角落
    Connections {
        target: WidgetState
        function onNotifOpenChanged() {
            if (WidgetState.notifOpen) {
                root.clearPopups();
                root.refreshSnapshot();
            } else {
                // 关掉面板就把快照丢掉，别让几十张卡片常驻
                root.snapshot = [];
            }
        }
    }

    // ==================== 与守护进程握手 ====================
    // 握手靠 socket：连上就发 {cmd:"hello"}，守护进程回一份全量。
    // 没有定时重试的定时器了 —— 断线由 Socket 自己重连。

    // 手工调试入口（正常数据走 socket）

    // ==================== 对外 IPC ====================
    IpcHandler {
        target: "notif"

        // 守护进程推数据（内部使用）
        function ingest(json: string): void {
            try {
                root.ingest(JSON.parse(json));
            } catch (e) {
                console.warn("notif: ingest 解析失败:", e);
            }
        }

        function open(): void {
            WidgetState.notifOpen = true;
        }

        function close(): void {
            WidgetState.notifOpen = false;
        }

        function toggle(): void {
            WidgetState.notifOpen = !WidgetState.notifOpen;
        }

        function toggleDnd(): void {
            root.toggleDnd();
        }

        function dismissAll(): void {
            root.dismissAll();
        }

        // 自检：qs ipc call notif dump → 历史 + 时间戳
        function dump(): string {
            return JSON.stringify({
                    popups: root.popups.length,
                    items: root.items.map(i => ({
                            id: i.id,
                            app: i.appName,
                            summary: i.summary,
                            timestamp: i.timestamp,
                            time: root.timeLabel(i.timestamp),
                            urgency: i.urgency,
                            actions: i.actions.length
                        }))
                });
        }
    }
}
