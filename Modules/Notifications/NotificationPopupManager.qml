import QtQuick
import Quickshell
import qs.Services
import org.kde.kirigami as Kirigami

QtObject {
	id: manager
	property var popupWindows: []
	property int spacing: Kirigami.Units.smallSpacing
	Instantiator {
		model: NotificationManager.sortedTemopraryNotifications
		delegate: NotificationPopup {
			// 这里可以直接访问 model 中的数据，例如 model.title
			index: index

			onReload: {
				// 直接操作 model，Instantiator 会自动销毁对应的 Popup 实体
				NotificationManager.dismiss(index, false);
			}
		}
		onObjectAdded: (index, object) => {
			// 可以在这里处理逻辑，或者直接用 Instantiator.objectAt(i)
		}
	}

}
