import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import qs.Services
import qs.Config
import qs.Widget
import qs.Modules.Bar.common
import org.kde.kirigami as Kirigami

// 顶栏蓝牙入口。外观与 Clipboard / Network / Volume 一致，统一来自 BarButton。
BarButton {
    id: root
    section: "right"

    // 注意不能叫 enabled —— Item 自带这个属性
    readonly property bool adapterOn: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.state === BluetoothAdapterState.Enabled

    icon: "preferences-system-bluetooth"
    text: {
        if (!Bluetooth.defaultAdapter)
            return "未检测到适配器";
        switch (Bluetooth.defaultAdapter.state) {
        case BluetoothAdapterState.Enabled:
            return "已开启";
        case BluetoothAdapterState.Disabled:
            return "已关闭";
        case BluetoothAdapterState.Enabling:
            return "打开中...";
        case BluetoothAdapterState.Disabling:
            return "关闭中...";
        case BluetoothAdapterState.Blocked:
            return "已禁用";
        default:
            return "未知状态";
        }
    }
    contentColor: root.adapterOn ? Kirigami.Theme.activeTextColor : Kirigami.Theme.negativeTextColor
    // 面板打开时点亮描边（IPC 打开也算）
    checked: bluetoothPanel.visible

    onClicked: bluetoothPanel.visible = !bluetoothPanel.visible

    BluetoothWidget {
        id: bluetoothPanel
        anchorItem: root
        visible: false
    }

    // IPC 控制面板（qs ipc call bt toggle）
    IpcHandler {
        target: "bt"

        function toggle() {
            bluetoothPanel.visible = !bluetoothPanel.visible;
        }

        function open() {
            bluetoothPanel.visible = true;
        }

        function close() {
            bluetoothPanel.visible = false;
        }
    }
}