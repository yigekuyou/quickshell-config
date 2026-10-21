//@ pragma UseQApplication
import Quickshell
import QtQuick

// ============================================================================
// Goose 聊天应用入口（独立配置）：
//   qs -p /home/light/.config/quickshell/Apps/Goose/main.qml
//
// 挂到主 shell 的话：
//   import qs.Apps.Goose
//   ShellRoot { GooseWindow {} }
// ============================================================================
ShellRoot {
    GooseWindow {}
}
