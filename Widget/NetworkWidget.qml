import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Services
import Quickshell.Io
import qs.config
import qs.Widget.common
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Networking
import org.kde.kirigami as Kirigami
import QtQuick.Controls
SlideWindow {
    id: root
    title: "网络配置"
    icon: "network-wireless"
    property var wifiDev: getWifiDevice()
    function getWifiDevice() {
	    return [...Networking.devices.values].find(d => d.type === DeviceType.Wifi);
    }
    headerTools: RowLayout {
        Theme {
            id: headerTheme
        }

        ToolButton {
		id: boolscan
		// Kirigami 推荐使用 icon.name 而非直接使用字体图标字符
		// "view-refresh" 是标准图标名，会自动匹配 Font Awesome 或 Breeze 图标库
		icon.name: wifiDev.scannerEnabled ? "view-refresh" : "edit-find"
		icon.width: Kirigami.Units.iconSizes.small
		icon.height: Kirigami.Units.iconSizes.small

		flat: true // 使其看起来像 header 上的工具按钮

		// 旋转动画：Kirigami 环境下依然建议保留动画逻辑
		RotationAnimation on rotation {
			running: wifiDev.scannerEnabled
			from: 0
			to: 360
			loops: Animation.Infinite
			duration: 1000
			onRunningChanged: if (!running) boolscan.rotation = 0
		}

		onClicked: {
			if (wifiDev) wifiDev.scannerEnabled = !wifiDev.scannerEnabled
		}

		ToolTip.visible: hovered
		ToolTip.text: wifiDev.scannerEnabled ? qsTr("正在扫描...") : qsTr("开始扫描")
	}

	Kirigami.Separator { Layout.fillHeight: true }

	// WiFi 开关部分
	Switch {
		id: wifiSwitch

		// 状态逻辑
		enabled: Networking.wifiHardwareEnabled
		checked: Networking.wifiEnabled && Networking.wifiHardwareEnabled

		// Kirigami 样式会自动处理颜色（primary color）和禁用状态的灰色
		// 不需要手动写 Rectangle 的 radius 和 color

		onToggled: {
			Networking.wifiEnabled = checked
		}

		ToolTip.visible: hovered
		ToolTip.text: !enabled ? qsTr("硬件已禁用") : (checked ? qsTr("WiFi 已开启") : qsTr("WiFi 已关闭"))
	}
    }

    Kirigami.ScrollablePage  {
	    leftPadding: 0
	    rightPadding: 0
	    topPadding: 0
	    bottomPadding: 0
	    anchors.margins: 0
	    // 选项卡切换 (Wi-Fi / Ethernet)
	    header:Kirigami.NavigationTabBar {
		    actions: [
			    Kirigami.Action {
				    text: "Wi-Fi"
				    icon.name: "network-wireless"
				    checked: true
				    onTriggered: contentStack.currentIndex = 0
			    },
			    Kirigami.Action {
				    text: "以太网"
				    icon.name: "network-wired"
				    onTriggered: contentStack.currentIndex = 1
			    }
		    ]
	    }StackLayout {

		    id: contentStack
		    // Wi-Fi 列表页
		    Kirigami.CardsListView {
			    Layout.fillHeight: true
			    Layout.margins: 0
			    model: wifiDev ? [...wifiDev.networks.values].sort((a, b) => {
				    if (a.connected !== b.connected) return b.connected - a.connected;
				    return b.signalStrength - a.signalStrength;
			    }) : []
			    delegate: Kirigami.AbstractCard {
				    contentItem: RowLayout {
					    ColumnLayout {
						    Layout.fillWidth: true
						    spacing: Kirigami.Units.smallSpacing

						    Kirigami.Heading {
							    text: modelData.name
							    level: 4
						    }
						    Label {
							    text: `${WifiSecurityType.toString(modelData.security)} | ${Math.round(modelData.signalStrength * 100)}%`
							    opacity: 0.7
							    Layout.fillWidth: true
							    font: Kirigami.Theme.smallFont
						    }
					    }

					    // 连接/断开 按钮组
					    RowLayout {
						    Button {
							    visible: !modelData.connected
							    text: "连接"
							    highlighted: true
							    onClicked: modelData.connect()
						    }

						    Button {
							    visible: modelData.connected
							    text: "断开"
							    Kirigami.Theme.colorSet: Kirigami.Theme.Critical
							    onClicked: modelData.disconnect()
						    }

						    ToolButton {
							    icon.name: "edit-delete"
							    visible: modelData.known
							    onClicked: modelData.forget()
							    ToolTip.text: "忘记网络"
						    }
					    }
				    }
			    }
		    }

		    // 以太网占位页
		    Kirigami.PlaceholderMessage {
			    icon.name: "network-wired"
			    text: "以太网设置暂不可用"
			    explanation: "请检查网线连接或稍后再试。"
		    }
	    }
    }
}
