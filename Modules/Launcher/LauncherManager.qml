import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

Item {
	id: root

	// 1. 必须持有引用，否则窗口会被销毁
	property var activeWindow: null

	function createWindow() {
		// 如果窗口已经存在，先销毁旧的（防止重复打开）
		if (activeWindow) {
			activeWindow.destroy();
			activeWindow = null;
		}

		const component = Qt.createComponent("Launcher.qml");

		if (component.status === Component.Ready) {
			// 2. 关键：调用 createObject 并指定 root 为父对象
			activeWindow = component.createObject(root);

			if (activeWindow === null) {
				console.error("实例化窗口对象失败");
			}
		} else if (component.status === Component.Error) {
			console.error("加载 Launcher.qml 失败:", component.errorString());
		}
	}

	IpcHandler {
		target: "launcher"
		function open() {
			// 3. 异步调用建议：有时 IPC 触发太快，UI 还没准备好
			createWindow();
			return "LAUNCHER_TOGGLED";
		}
	}
}
