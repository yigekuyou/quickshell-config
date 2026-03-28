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
    property real notiftimeout: 5 *60
    property int notifnumber: 5
    property int exitDuration: 300
    property var timeQueue: []
    signal requestExit()
    onDndChanged: {
        if (dnd) {
            root.temporaryNotifications = [];
        }
    }
    property var timers: ({})

    // 监听通知服务器的通知列表变化
    Connections {
	    target: notificationsServer
	    onNotification: (notification)=> {
		    notification.tracked = true;
		    root.timeQueue.unshift({
			    "id": notification.id,
			    "t": Date.now()
		    });
		    if (!root.dnd && notification.urgency != NotificationUrgency.Critical) {
			    root.temporaryNotifications.unshift(notification);
		    } else if (notification.urgency == NotificationUrgency.Critical) {
			    root.temporaryNotifications.unshift(notification);
		    }
		    if (root.temporaryNotifications.length>notifnumber) {
			    temporaryNotifications.pop();
		    }
	    }
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
		    let now = Date.now();
console.log(now)
		    while (root.temporaryNotifications.length > 0) {
			    let lastItem = root.timeQueue[timeQueue.findIndex(item => item.id === root.temporaryNotifications[length-1].id)];

			    if (now - lastItem.t > 5) {
				    // 已经过期，从队列弹出
				    root.temporaryNotifications.pop();
			    } else {
				    // 如果最老的一条都没过期，后面的肯定也没过期，直接跳出
				    break;
			    }
		    }

	    });
    }
    function dismiss(notification, parmanent = false) {
        const index = root.temporaryNotifications.indexOf(notification);

        if (index !== -1) {
            root.temporaryNotifications.splice(index, 1);
        }

        if (parmanent) {
            notification.dismiss();
	    timeQueue.splice(timeQueue.findIndex(item => item.id === notification.id),1);
        }
    }

    function dismissAll() {
        temporaryNotifications = [];
	timeQueue=[]

        const notifications = [...notificationsServer.trackedNotifications.values];

        notifications.forEach(n => {
            n.dismiss();
        });
    }
    Timer {
	    id:tempnotif
	    interval: 1000; running: (root.temporaryNotifications.length >0); repeat: true
	    onTriggered:{
		    closenotif()
	}
    }
    Timer {
	    interval: 500
	    running: true
	    repeat: true
	    onTriggered: {
		    if (root.timeQueue.length === 0) return;

		    let now = Date.now();

		    // 3. 轮询检查尾部（老数据）
		    // 使用 while 处理同一时间内可能过期的多条通知
		    while (root.timeQueue.length > 0) {
			    let lastItem = root.timeQueue[root.timeQueue.length - 1];

			    if (now - lastItem.t > root.notiftimeout) {
				    // 已经过期，从计时队列弹出
				    root.timeQueue.pop();
				   root.dismiss(mergedNotifications.find(item => item.id === lastItem.id),true)
			    } else {
				    // 如果最老的一条都没过期，后面的肯定也没过期，直接跳出
				    break;
			    }
		    }
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
