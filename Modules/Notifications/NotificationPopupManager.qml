import QtQuick
import Quickshell
import qs.Services
import org.kde.kirigami as Kirigami

Item {
	id: manager
	property var temporaryNotifications: []
	property int spacing: Kirigami.Units.smallSpacing
	Connections {
		target: NotificationManager.notificationsServer
		enabled: NotificationManager.notificationsServer !== null
		onNotification: function (notification) {
			if (!NotificationManager.dnd && notification.urgency != NotificationUrgency.Critical) {
				manager.temporaryNotifications.unshift(notification);
			} else if (notification.urgency == NotificationUrgency.Critical) {
				manager.temporaryNotifications.unshift(notification);
			}
		}
	}
	Instantiator {
		model: manager.temporaryNotifications
		delegate: NotificationPopup {
			// 这里可以直接访问 model 中的数据，例如 model.title
			index: index
			notificationData:modelData
			onReload: {
				// 直接操作 model，Instantiator 会自动销毁对应的 Popup 实体
				const index = manager.temporaryNotifications.indexOf(modelData);

				if (index !== -1) {
					manager.temporaryNotifications.splice(index, 1);
				}
			}
		}
	}
}
