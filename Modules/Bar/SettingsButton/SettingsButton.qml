import QtQuick
import QtQuick.Controls
import qs.Config
import qs.Modules.Bar.common
import org.kde.kirigami as Kirigami

// 顶栏最左边的设置入口（就是 dots-hyprland 那个齿轮位）。
// 图标走系统图标主题（Breeze: actions/16/settings-configure.svg），
// 外观/点击交给 common/BarButton，跟其它 bar 按钮同一套胶囊。
//
// 打开的是 Modules/Settings/SettingsWindow.qml —— 已经有一个
// IpcHandler target "settings" 在那里注册（`qs ipc call settings toggle`），
// 这里不再重复注册，只翻转同一个 WidgetState.settingsOpen。
BarButton {
    id: root
    section: "left"

    icon: "settings-configure"
    iconSize: Math.round(Kirigami.Units.gridUnit * 0.9)
    square: true
    checked: WidgetState.settingsOpen
    onClicked: WidgetState.settingsOpen = !WidgetState.settingsOpen
}