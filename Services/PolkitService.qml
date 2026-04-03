//PolkitService.qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Polkit

Singleton {
    id: root

    // 保留环境变量开关，方便特殊情况下手动禁用

    // 直接作为属性导出，供外部访问
    readonly property alias agent: polkitAgent

    // 静态实例化 PolkitAgent
    PolkitAgent {
        id: polkitAgent
        onAuthenticationRequestStarted: {
		//console.log("Polkit: 收到验证请求 - ", flow.actionId);
		//console.log("Polkit: 收到验证请求 - ", JSON.stringify(flow.selectedIdentity);
	}
    }
}
