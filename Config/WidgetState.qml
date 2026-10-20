pragma Singleton
import QtQuick

// 全局弹窗 / 窗口开关。
// 只放“谁都能改、谁都要看”的开关；组件自己的临时状态（比如 Cava 展开）
// 留在组件内部，不要往这里堆。
QtObject {
    property bool networkOpen: false
    property bool audioOpen: false
    property bool notifOpen: false
    // 设置窗口（Modules/Settings/SettingsWindow.qml）
    property bool settingsOpen: false
}