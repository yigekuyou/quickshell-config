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
    signal requestExit()
    onDndChanged: {
        if (dnd) {
            root.temporaryNotifications = [];
        }
    }
    ElapsedTimer {
	    id: elapsedTimer
    }

    // 监听通知服务器的通知列表变化
    Connections {
	    target: notificationsServer
	    enabled: notificationsServer !== null
	    onNotification: function (notification) {
		    notification.tracked = true;
		    if (elapsedTimer.elapsed() >= 0.1 && !root.dnd && notification.urgency != NotificationUrgency.Critical) {
			    root.temporaryNotifications.push(notification);
			    let timeout = root.notiftimeout*60 *1000;
			    let timer = Qt.createQmlObject("import QtQuick; Timer {}", root);

			    if (timer) {
				    timer.interval = timeout;
				    timer.repeat = false;
				    timer.triggered.connect(function() {
					    root.dismiss(notification, true);
					    timer.destroy();
				    });
				    timer.start();
			    }
		    if (!root.dnd && notification.urgency != NotificationUrgency.Critical) {
			    root.temporaryNotifications.unshift(notification);
		    } else if (notification.urgency == NotificationUrgency.Critical) {
			    root.temporaryNotifications.unshift(notification);
		    }
		    if (root.temporaryNotifications.length>root.notifnumber) {
			    temporaryNotifications.pop();
		    }
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
        keepOnReload: false
    }
}
