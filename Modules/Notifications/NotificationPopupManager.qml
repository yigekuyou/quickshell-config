import QtQuick
import Quickshell
import qs.Services
import org.kde.kirigami as Kirigami

Item {
	id: manager
	property var popupWindows: []
	property int spacing: Kirigami.Units.smallSpacing
	Connections {
		target: NotificationManager.notificationsServer
		enabled: NotificationManager.notificationsServer !== null
		onNotification: function (notification) {
			if (!NotificationManager.dnd && notification.urgency != NotificationUrgency.Critical) {
				NotificationManager.temporaryNotifications.unshift(notification);
			} else if (notification.urgency == NotificationUrgency.Critical) {
				NotificationManager.temporaryNotifications.unshift(notification);
			}
		}
	}
	Instantiator {
		model: NotificationManager.sortedTemopraryNotifications
		delegate: NotificationPopup {
			// 这里可以直接访问 model 中的数据，例如 model.title
			index: index
			onReload: {
				// 直接操作 model，Instantiator 会自动销毁对应的 Popup 实体
				NotificationManager.dismiss(modelData, false);
			}
		}
		onObjectAdded: (index, object) => {
			// 可以在这里处理逻辑，或者直接用 Instantiator.objectAt(i)
		}
	}

}
