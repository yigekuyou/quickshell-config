import QtQuick
import Quickshell
import qs.Services
import org.kde.kirigami as Kirigami

QtObject {
	id: manager
	property var popupWindows: []
	property int spacing: Kirigami.Units.smallSpacing

	property Component popupComponent: Component {
		NotificationPopup {
			onReload:{
				manager._destroyWindowAtIndex(manager.popupWindows.length-1);
			}
		}
	}

	property Connections serviceListener: Connections {
		target: NotificationManager
		function onTemporaryNotificationsChanged() {
			const dataList = NotificationManager.sortedTemopraryNotifications;
			const currentWinCount = manager.popupWindows.length;
			const newDataCount = dataList.length;

			// 1. 增量创建：只为新加的索引创建窗口
			if (newDataCount > currentWinCount) {
				for (let i = currentWinCount; i < newDataCount; i++) {
					manager._createWindowForIndex(i);
				}
			}

			// 2. 尾部同步：如果数据源减少了，销毁多余的窗口
			if (newDataCount < currentWinCount) {
				for (let i = currentWinCount - 1; i >= newDataCount; i--) {
					manager._destroyWindowAtIndex(i);
				}
			}
		}
		function onRequestExit(){
					manager._destroyWindowAtIndex(manager.popupWindows.length);
		}
	}
	function _createWindowForIndex(idx, data) {
		const win = popupComponent.createObject(null, {
			"index": idx // 在 NotificationPopup 内部定义这个属性
		});

		if (win) {
			popupWindows.push(win);
			popupWindows = popupWindows; // 触发属性通知
		}
	}

	function _destroyWindowAtIndex(idx) {
		let win = popupWindows[idx];
		if (win) {
			// 如果有退出动画，可以在这里触发
			if (win.startExit) {
				win.startExit();
				// 动画完成后逻辑应由 win 自身 handle，或者直接销毁
			}
			win.destroy();
		}
		popupWindows.splice(idx, 1);
		popupWindows = popupWindows;
	}

	function _updatePositions() {
		let currentYOffset = 0;
		for (let i = 0; i < popupWindows.length; i++) {
			let win = popupWindows[i];
			win.targetYOffset = currentYOffset;
			currentYOffset += (win.implicitHeight || win.height || 0) + spacing;
		}
	}
}
