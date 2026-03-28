pragma Singleton
import Quickshell
import Quickshell.Services.Notifications
import QtQuick

Singleton {
    id: root
    property list<Notification> mergedNotifications: notificationsServer.trackedNotifications.values
    readonly property bool isNotifMode: NotificationManager.temporaryNotifications.length > 0
    property list<Notification> temporaryNotifications: []
    readonly property list<Notification> sortedTemopraryNotifications: sortNotifications(temporaryNotifications)
    property bool dnd: false
    property real notiftimeout: 5
    property int notifnumber: 5
    property int exitDuration: 300
    property var timers: ({})

    signal requestExit()
    onDndChanged: {
        if (dnd) {
            root.temporaryNotifications = [];
        }
    }

    // 监听通知服务器的通知列表变化
    Connections {
	    target: notificationsServer
	    onNotification: (notification)=> {
		    notification.tracked = true;
		    if (!root.dnd && notification.urgency != NotificationUrgency.Critical) {
			    root.temporaryNotifications.unshift(notification);
		    } else if (notification.urgency == NotificationUrgency.Critical) {
			    root.temporaryNotifications.unshift(notification);
		    }
		    if (root.temporaryNotifications.length > root.notifnumber) {
			    root.temporaryNotifications.pop();
		    }
		    root.startTimerFor(notification);
	    }
    }
    function setTimeout(callback, delay) {
	    if (delay <= 0) {
		    callback();
		    return null;
	    }

	    // 动态创建一个 Timer 组件
	    // arg1: QML 字符串, arg2: 父对象, arg3: 用于调试的名称
	    let timer = Qt.createQmlObject(`
	    import QtQuick 2.0
	    Timer {
		    interval: ${delay};
		    running: true;
		    repeat: false;
		    onTriggered: {
			    callback();
			    destroy(); // 执行完后自动销毁自己，释放内存
		    }
	    }
	    `, root, "DynamicTimer");

	    // 绑定 callback 逻辑
	    timer.triggered.connect(callback);
	    return timer;
    }

    function clearTimeout(timerId) {
	    if (timerId) {
		    timerId.stop();
		    timerId.destroy();
	    }
    }
    function startTimerFor(notification) {
	    stopTimerFor(notification.id);
	    let timeoutMs = notification.expireTimeout * 1000;
	    // 如果客户端没给时间 (<0)，使用默认设置 (分钟转毫秒)
	    if (timeoutMs <= 0) {
		    timeoutMs = notiftimeout * 60 * 1000;
	    }

	    let timerId = setTimeout(function() {
		    console.log("Notification expired:", notification.id);

		    // 从本地暂存列表移除
		    removeNotificationById(notification.id);
			notification.expire();
		    delete timers[notification.id];
	    }, timeoutMs);

	    timers[notification.id] = timerId;
    }

    function stopTimerFor(id) {
	    if (timers[id]) {
		    clearTimeout(timers[id]);
		    delete timers[id];
	    }
    }
    function removeNotificationById(targetId) {
	    requestExit();
	    Qt.callLater(function() {
	let index = temporaryNotifications.findIndex(item => item.id === targetId);
	    temporaryNotifications.splice(index, 1);
	    });
    }
    function sortNotifications(notifications) {
        notifications = notifications.slice().filter(item => item != null);

        return notifications.sort((a, b) => {
            if ((a.urgency == NotificationUrgency.Critical) != (b.urgency == NotificationUrgency.Critical)) {
                return a.urgency == NotificationUrgency.Critical ? -1 : 1;
            }
            if (b.id > a.id) return 1;
	    if (b.id < a.id) return -1;

	    return 0;
        });
    }
    function closenotif() {
	    requestExit();
	    Qt.callLater(function() {
	    for (let i = temporaryNotifications.length ; i >= notifnumber; i--) {
		    temporaryNotifications.pop();
	    }
	    temporaryNotifications.pop();
	    });
    }
    function dismiss(notification, parmanent = false) {
        const index = root.temporaryNotifications.indexOf(notification);

        if (index !== -1) {
            root.temporaryNotifications.splice(index, 1);
        }

        if (parmanent) {
            notification.dismiss();
        }
    }

    function dismissAll() {
        temporaryNotifications = [];

        const notifications = [...notificationsServer.trackedNotifications.values];

        notifications.forEach(n => {
            n.dismiss();
        });
    }
    Timer {
	    id:tempnotif
	    interval: 5000; running: (temporaryNotifications.length>0); repeat: true
	    onTriggered:{
		    closenotif()
	}
    }
    NotificationServer {
        id: notificationsServer
        actionsSupported: true
        bodyHyperlinksSupported: true
        actionIconsSupported: true
        persistenceSupported: false
        bodyImagesSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        imageSupported: true
        keepOnReload: true

    }
}
