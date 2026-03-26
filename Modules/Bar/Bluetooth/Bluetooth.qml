import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Services
import qs.Config
import qs.Widget
import Quickshell.Bluetooth
import org.kde.kirigami as Kirigami

Kirigami.ShadowedRectangle {
    id: root
    // --- 样式配置 ---
    implicitWidth: layout.implicitWidth + Kirigami.Units.largeSpacing * 2
    implicitHeight: Sizes.barHeight

    // 使用 Kirigami 主题色配合半透明效果
    color: Qt.alpha(Kirigami.Theme.backgroundColor, 0.5)
    radius: Sizes.cornerRadius
    shadow.color: Qt.rgba(0, 0, 0, 0.2)
    shadow.size: 10
    shadow.yOffset: 2
    border.width: 1
    border.color: Qt.alpha(Kirigami.Theme.dividerColor, 0.3)
    // --- 【2】 实例化网络面板 ---
    BluetoothWidget {
        id: bluetoothPanel
        // 默认是关闭的
        visible: false

        // 如果你想让面板的配色跟随全局 Colorscheme，可以在这里覆盖内部属性
        // (前提是 NetworkWidget 内部没有把这些属性写死，而是开放了别名或者属性)
        // 目前你的 NetworkWidget 是自包含配色的，直接用即可。
    }

    // --- 交互区域 ---
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        // --- 【3】 修改点击逻辑 ---
        onClicked: {
            // 切换面板的开关状态
            bluetoothPanel.visible = !bluetoothPanel.visible;
        }
    }
RowLayout {
	id: layout
	anchors.centerIn: parent
	spacing: Kirigami.Units.smallSpacing
	anchors.fill: parent
            Layout.fillWidth: true
                        Kirigami.Icon {
				Layout.preferredWidth: Kirigami.Units.gridUnit
				Layout.preferredHeight: Kirigami.Units.gridUnit

				// 使用系统标准蓝牙图标
				source: "preferences-system-bluetooth"

				// 颜色反馈：仅在 Enabled 状态下使用高亮色，其余使用负面或中性色
				color: (Bluetooth.defaultAdapter.state === BluetoothAdapterState.Enabled)
				? Kirigami.Theme.activeTextColor
				: Kirigami.Theme.negativeTextColor
			}
			Label {
				text: {
					switch (Bluetooth.defaultAdapter.state) {
						case BluetoothAdapterState.Enabled:   return "已开启";
						case BluetoothAdapterState.Disabled:  return "已关闭";
						case BluetoothAdapterState.Enabling:  return "打开中...";
						case BluetoothAdapterState.Disabling: return "关闭中...";
						case BluetoothAdapterState.Blocked:   return "已禁用";
						default:                              return "未知状态";
					}
				}
				font.bold: true
				font.pixelSize: Kirigami.Units.gridUnit * 0.8

				// 文字颜色同步图标颜色
				color: (Bluetooth.defaultAdapter.state === BluetoothAdapterState.Enabled)
				? Kirigami.Theme.activeTextColor
				: Kirigami.Theme.negativeTextColor
                    }
                }
}
