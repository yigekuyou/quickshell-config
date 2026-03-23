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
			onExitFinished: manager._destroyWindow(this)
		}
	}

	property Connections serviceListener: Connections {
		target: NotificationManager
		function onTemporaryNotificationsChanged() {
			// 直接对比长度或索引来决定操作
			manager._syncByIndex(NotificationManager.temporaryNotifications);
		}
	}

	/**
	 * 修改后的同步逻辑：基于索引的差异处理
	 */
	function _syncByIndex(newList) {
		const currentCount = popupWindows.length;
		const newCount = newList.length;

		// 1. 如果新列表更长：说明有新通知加入（通常在末尾）
		if (newCount > currentCount) {
			for (let i = currentCount; i < newCount; i++) {
				_createWindow(NotificationManager.temporaryNotifications[i]);
			}
		}
		// 2. 如果新列表变短：说明最后一个通知被移除（或通知减少）
		else if (newCount < currentCount) {
			// 从后往前删除多余的窗口
			for (let i = currentCount - 1; i >= newCount; i--) {
				let win = popupWindows[i];
				if (win.startExit) {
					win.startExit(); // 触发退出动画
				} else {
					_destroyWindow(win);
				}
			}
		}
		_updatePositions();
	}

	function _createWindow(notification) {
		// 检查是否已经存在（防止重复创建相同索引的对象）
		if (_isWindowExists(notification)) return;

		const win = popupComponent.createObject(null, {
			"notificationData": notification
		});

		if (win) {
			popupWindows.push(win);
			// 在 QML 中修改数组需要重新赋值以触发属性通知
			popupWindows = popupWindows;
		}
	}

	function _destroyWindow(win) {
		if (!win) return;
		const idx = popupWindows.indexOf(win);
		if (idx !== -1) {
			popupWindows.splice(idx, 1);
			popupWindows = popupWindows;
			win.destroy();
			_updatePositions();
		}
	}

	function _updatePositions() {
		let currentYOffset = 0;
		// 按照 popupWindows 的物理索引顺序排列位置
		for (let i = 0; i < popupWindows.length; i++) {
			let win = popupWindows[i];
			win.targetYOffset = currentYOffset;
			currentYOffset += (win.implicitHeight || 0) + spacing;
		}
	}

	function _isWindowExists(notification) {
		return popupWindows.some(p => p.notificationData === notification);
	}
}
