//PolkitAuthPopupManager.qml
import QtQuick
// 确保导入路径正确，这里假设您的 Singleton 注册名为 PolkitService
import qs.Services

Item {
	id: root

	// 统一使用此属性引用当前的认证窗口实例
	property var activeWindow: null

	Connections {
		target: PolkitService.agent

		// 监听 flow 属性的变化
		function onFlowChanged() {
			const currentFlow = PolkitService.agent.flow;

			if (currentFlow) {
				// 如果有新请求且当前没有窗口，则创建
				if (!activeWindow) {
					createWindow(currentFlow);
				}
			} else {
				// 如果 flow 变为 null（认证完成、取消或失败），销毁窗口
				destroyWindow();
			}
		}
	}

	function createWindow(flow) {
		const component = Qt.createComponent("PolkitAuthPopup.qml");

		if (component.status === Component.Ready) {
			finishCreation(component, flow);
		} else if (component.status === Component.Error) {
			console.error("加载 PolkitAuthPopup.qml 失败:", component.errorString());
		} else {
			// 处理异步加载
			component.statusChanged.connect(() => {
				if (component.status === Component.Ready) {
					finishCreation(component, flow);
				}
			});
		}
	}

	function finishCreation(component, flow) {
		// 创建对象并传递 authFlow
		activeWindow = component.createObject(root, { "authFlow": flow });

		if (activeWindow) {
			activeWindow.forceActiveFocus();
			// 监听窗口自身的销毁信号，防止内存泄漏或状态不同步
			activeWindow.Component.destruction.connect(() => {
				activeWindow = null;
			});
		}
	}

	function destroyWindow() {
		if (activeWindow) {
			activeWindow.destroy();
			activeWindow = null;
		}
	}
}
