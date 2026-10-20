pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.Config

// 通知中心 / 弹窗的唯一数据源。
//
// 本进程内只能存在一个 NotificationServer：D-Bus 上
// org.freedesktop.Notifications 是独占名字，第二个实例抢不到名字，
// 表现为“通知不出现 / 发通知的应用超时 / 旧配置里另起 qs --path Notif.qml
// 的子进程与主进程互抢名字”。所以历史上被切出去的那个子进程已经删掉，
// 所有通知相关的东西都走这个单例。
Singleton {
    id: root

    // ==================== 可调参数 ====================
    readonly property int maxPopups: 3          // 屏幕右上角同时最多显示几张
    readonly property int defaultTimeout: 6000  // 客户端传 -1 时的停留时长
    readonly property int maxTimeout: 20000     // 客户端要求再久也最多留这么久

    property bool dnd: false

    // ==================== 通知列表 ====================
    readonly property var trackedModel: server.trackedNotifications

    // 顶栏徽标只要条数，不要排序，避免每条通知都排一次序
    readonly property int count: root.trackedModel && root.trackedModel.values ? root.trackedModel.values.length : 0

    // 通知中心用的排序快照。
    //
    // 为什么要一个快照而不是直接绑定 trackedNotifications：
    // 面板里每条通知是一整棵 FormCard，模型一变 Repeater 会全量重建。
    // 以前绑在 .values 上，来一条通知就重建四十张卡；洪水通知时主线程被这点
    // 活彻底占满，看着就是「通知一多 qs 就卡死、内存还一直涨」。
    // 现在：面板关着时快照就是空的（零开销），开着时把短时间内的多次变化
    // 合并成一次刷新。
    property var snapshot: []
    readonly property int snapshotInterval: 120

    function refreshSnapshot() {
        const src = root.trackedModel ? root.trackedModel.values : null;
        const list = src ? [...src] : [];
        list.sort((a, b) => {
            const ac = a.urgency === NotificationUrgency.Critical;
            const bc = b.urgency === NotificationUrgency.Critical;
            if (ac !== bc)
                return ac ? -1 : 1;
            return b.id - a.id;   // id 单调递增，越大越新
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

    Connections {
        target: root.trackedModel
        enabled: root.trackedModel !== null
        function onValuesChanged() {
            // 面板没开就完全不计算；开着也只排一次队
            if (WidgetState.notifOpen)
                snapshotTimer.restart();
        }
    }

    // ==================== 弹窗队列 ====================
    // 元素是 Notification 对象本身。每次都整体替换数组，Repeater/ListView 才会重排。
    property var popups: []
    readonly property bool hasPopups: popups.length > 0

    function isShowing(n) {
        if (!n)
            return false;
        for (let i = 0; i < root.popups.length; i++) {
            if (root.popups[i] === n || root.popups[i].id === n.id)
                return true;
        }
        return false;
    }

    function addPopup(n) {
        if (!n)
            return;
        // 同一个通知被 replaces_id 更新时不要叠两张：先摘掉旧的再插到最前
        const next = root.popups.filter(p => p === n ? false : p.id !== n.id);
        next.unshift(n);
        // 超出上限的从队尾丢弃（仍然留在历史列表里，不会丢）
        while (next.length > root.maxPopups)
            next.pop();
        root.popups = next;
    }

    function removePopup(n) {
        if (!n)
            return;
        const next = root.popups.filter(p => p !== n && p.id !== n.id);
        if (next.length !== root.popups.length)
            root.popups = next;
    }

    function clearPopups() {
        if (root.popups.length > 0)
            root.popups = [];
    }

    // ==================== 操作 ====================
    function dismiss(n) {
        if (!n)
            return;
        root.removePopup(n);
        n.dismiss();
    }

    // 超时自动消失：语义上是 Expired 而不是用户主动关闭
    function expire(n) {
        if (!n)
            return;
        root.removePopup(n);
        n.expire();
    }

    function dismissAll() {
        root.clearPopups();
        const list = server.trackedNotifications ? [...server.trackedNotifications.values] : [];
        for (let i = 0; i < list.length; i++) {
            if (list[i])
                list[i].dismiss();
        }
    }

    function toggleDnd() {
        root.dnd = !root.dnd;
    }

    // 通知中心的历史上限。trackedNotifications 本身不会自动清理，
    // 一天下来能攒到几百条并一直占内存。
    readonly property int maxHistory: 40

    // pending: 是否有一条正在插入（tracked=true 的插入时机是延后的，
    // 调用时 values 里还没有它，所以要自己加一）
    function trimHistory(pending) {
        if (!server.trackedNotifications)
            return;
        // 数组按 model 顺序（旧的在前）；超出的从最老的开始摘
        const values = [...server.trackedNotifications.values];
        let overflow = values.length + (pending ? 1 : 0) - root.maxHistory;
        for (let i = 0; i < values.length && overflow > 0; i++) {
            const n = values[i];
            // 正在显示的弹窗先留着，等它自己消失
            if (!n || root.isShowing(n))
                continue;
            n.tracked = false;
            overflow--;
        }
    }

    onDndChanged: {
        if (root.dnd)
            root.clearPopups();
    }

    // 通知中心一打开就把右上角的弹窗收掉，否则两摞东西叠在同一个角落，
    // 下面那摞还点不到。
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

    // ==================== 通知服务器 ====================
    Connections {
        target: server
        function onNotification(notification) {
            if (!notification)
                return;
            // tracked：让它留在 trackedNotifications 里，通知中心才有历史
            notification.tracked = true;
            // 历史不要无限增长：超过上限就把最老的从列表里摘掉
            // （只置 tracked=false，不调用 dismiss，免得给应用发 NotificationClosed）
            root.trimHistory(true);
            // 应用自己撤销 / 用户从别处关掉时，把弹窗一起收掉
            notification.closed.connect(function (reason) {
                root.removePopup(notification);
            });
            if (!root.dnd && !WidgetState.notifOpen)
                root.addPopup(notification);
        }
    }

    NotificationServer {
        id: server
        // 能力声明保守一点：不支持正文标记/回复，避免把带 HTML 的正文
        // 原样塞进 Text 里导致排版炸掉（弹窗没有键盘焦点，做不了行内回复）。
        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: true
        imageSupported: true
        inlineReplySupported: false
        persistenceSupported: false
        // 热重载时保住 D-Bus 名字，否则每次改配置都会短暂丢失通知服务
        keepOnReload: true
    }

    IpcHandler {
        target: "notif"

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
    }
}
