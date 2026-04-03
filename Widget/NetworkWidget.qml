import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Services
import Quickshell.Io
import qs.Config
import qs.Widget.common
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Networking
import org.kde.kirigami as Kirigami
import QtQuick.Controls
import org.kde.kirigamiaddons.formcard as FormCard

SlideWindow {
    id: root
    title: "网络配置"
    icon: "network-wireless"
    property string currentTab: "wifi" // 用于切换视图的 ID
    property var wifiDev: getWifiDevice()
    function getWifiDevice() {
        return [...Networking.devices.values].find(d => d.type === DeviceType.Wifi);
    }
    Kirigami.PromptDialog {
	    id: pskDialog
	    title: qsTr("连接到 %1").arg(targetNetwork.name)
	    subtitle: qsTr("此网络需要密码")
	    property var targetNetwork: null
	    standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel

	    // 绑定确认按钮逻辑
	    onAccepted: {
		    if (passwordField.text.length > 0) {
			    targetNetwork.connectWithPsk(passwordField.text);
			    passwordField.text = ""; // 清空
		    }
	    }

	    // 输入控件
	    Kirigami.PasswordField {
		    id: passwordField
		    placeholderText: qsTr("输入密码...")
		    implicitWidth: parent.implicitWidth
		    // 按回车键直接触发 Ok 按钮
		    onAccepted: pskDialog.accept()
	    }
    }
    headerTools: RowLayout {
        Theme {
            id: headerTheme
        }

        ToolButton {
            id: boolscan
            action: Kirigami.Action {
                // Kirigami 推荐使用 icon.name 而非直接使用字体图标字符
                // "view-refresh" 是标准图标名，会自动匹配 Font Awesome 或 Breeze 图标库
                icon.name: wifiDev.scannerEnabled ? "view-refresh" : "edit-find"
                icon.width: Kirigami.Units.iconSizes.small
                icon.height: Kirigami.Units.iconSizes.small
                checkable: true
                onTriggered: {
                    if (wifiDev)
                        wifiDev.scannerEnabled = !wifiDev.scannerEnabled;
                }
            }
            // 旋转动画：Kirigami 环境下依然建议保留动画逻辑
            RotationAnimation on rotation {
                running: wifiDev.scannerEnabled
                from: 0
                to: 360
                loops: Animation.Infinite
                duration: 1000
                onRunningChanged: if (!running)
                    boolscan.rotation = 0
            }
            ToolTip.visible: hovered
            ToolTip.text: wifiDev.scannerEnabled ? qsTr("正在扫描...") : qsTr("开始扫描")
        }

        Kirigami.Separator {
            Layout.fillHeight: true
        }

        // WiFi 开关部分
        Switch {
            id: wifiSwitch

            // 状态逻辑
            enabled: Networking.wifiHardwareEnabled
            checked: Networking.wifiEnabled && Networking.wifiHardwareEnabled

            // Kirigami 样式会自动处理颜色（primary color）和禁用状态的灰色
            // 不需要手动写 Rectangle 的 radius 和 color

            onToggled: {
                Networking.wifiEnabled = checked;
            }

            ToolTip.visible: hovered
            ToolTip.text: !enabled ? qsTr("硬件已禁用") : (checked ? qsTr("WiFi 已开启") : qsTr("WiFi 已关闭"))
        }
    }
    Kirigami.NavigationTabBar {
        Layout.fillWidth: true

        actions: [
            Kirigami.Action {
                text: "Wi-Fi"
                icon.name: "network-wireless"
                checked: root.currentTab === "wifi"
                onTriggered: root.currentTab = "wifi"
            },
            Kirigami.Action {
                text: "以太网"
                icon.name: "network-wired"
                checked: root.currentTab === "wired"
                onTriggered: root.currentTab = "wired"
            }
        ]
    }
    Repeater {
        model: wifiDev ? [...wifiDev.networks.values].sort((a, b) => {
            if (a.connected !== b.connected)
                return b.connected - a.connected;
            return b.signalStrength - a.signalStrength;
        }) : []

        Layout.fillWidth: true
        Layout.margins: 0

        FormCard.FormCard {
            id: wifiComp
            visible: root.currentTab === "wifi"
            Layout.fillWidth: true
            FormCard.FormButtonDelegate {
		    text: modelData.name || "未知设备"
		    description:  `${WifiSecurityType.toString(modelData.security)} | ${Math.round(modelData.signalStrength * 100)}%`
		    BusyIndicator {
			    anchors.fill: parent
			    running: modelData.stateChanging
			    visible: running
		    }

		    trailing: Row {
			    ToolButton {
				    icon.name: modelData.connected ? "network-disconnect" : "network-connect"
				    // 只有当前项没有连接时才显示“连接”
				    visible: true
				    onClicked: {
					    if (modelData.connected) {
						    modelData.disconnect();
					    } else {
						    modelData.connect();
					    }
				    }
				    ToolTip.visible: hovered
				    ToolTip.text: modelData.connected ? qsTr("断开连接") : qsTr("连接")
			    }
			    Connections {
				    target: modelData
				    function onConnectionFailed(reason) {
					    console.log(ConnectionFailReason.toString(reason))
					    // 如果失败原因是缺少凭据 (NoSecrets)
					    if (reason === ConnectionFailReason.NoSecrets) {
						    pskDialog.targetNetwork = modelData;
						    pskDialog.open();
					    }
				    }
			    }
			    ToolButton {
				    icon.name: "database-change-key"
				    visible: {
					    if(!modelData.known) return false;
					    const security = modelData.security;
					    const needsPsk = (security === WifiSecurityType.WpaPsk ||
					    security === WifiSecurityType.Wpa2Psk ||
					    security === WifiSecurityType.Sae);
					    return needsPsk
				}
				    onClicked: {
					    pskDialog.targetNetwork = modelData;
					    pskDialog.open();
				}

				    ToolTip.visible: hovered
				    ToolTip.text: qsTr("修改密码")

			    }
			    // 忘记网络按钮
			    ToolButton {
				    icon.name: "edit-delete"
				    visible: modelData.known
				    onClicked: modelData.forget()

				    ToolTip.visible: hovered
				    ToolTip.text: qsTr("忘记网络")
			    }
		    }
            }
        }
    }

    // 以太网占位部分
    FormCard.FormCard {
	    visible: root.currentTab === "wired" ||!Networking.wifiEnabled && root.currentTab === "wifi"
	    Layout.fillWidth: true
	    FormCard.FormHeader { title: "有线网络连接" }
	    Kirigami.PlaceholderMessage {
		    id:wiredLyout
		    visible:root.currentTab === "wired"
		    icon.name: "network-wired"
		    text: "以太网设置暂不可用"
		    explanation: "占位符"
	    }
	    Kirigami.PlaceholderMessage {
		    id: offMessage
		    // 控制显示：当 WiFi 关闭时显示
		    visible: !Networking.wifiEnabled && root.currentTab === "wifi"

		    icon.name: "network-wireless-off"
		    text: "Wi-Fi 已关闭"
		    explanation: "请在上方开关处开启 Wi-Fi 和扫描可用网络。"
	    }
    }
}
