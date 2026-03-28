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
    property real notiftimeout: 300000
    property int notifnumber: 5
    property int exitDuration: 300
    signal requestExit()
    onDndChanged: {
        if (dnd) {
            root.temporaryNotifications = [];
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
        onNotification: (notification)=> {
            notification.tracked = true;
            if (!root.dnd && notification.urgency != NotificationUrgency.Critical) {
                root.temporaryNotifications.unshift(notification);
            } else if (notification.urgency == NotificationUrgency.Critical) {
                root.temporaryNotifications.unshift(notification);
            }
        }
    }
}
