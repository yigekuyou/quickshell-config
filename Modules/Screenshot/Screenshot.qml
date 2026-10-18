import QtQuick
import Quickshell
import Quickshell.Io
import qs.Config

Item {
    id: root

    // 截图基于 wlroots 工具链（Hyprland/Sway 等）：
    //   grim   - 输出 PNG 到 stdout
    //   slurp  - 区域选择
    //   wl-copy - 写入剪贴板（后台守护选择，退出后内容仍在）
    Process {
        id: shotProc
    }

    IpcHandler {
        target: "shot"

        // 全屏截图 → 剪贴板
        // 触发：quickshell ipc call shot shot（绑定到合成器快捷键）
        function shot() {
            shotProc.exec(["sh", "-c", "grim - | wl-copy"])
        }

        // 区域截图 → 剪贴板
        // 触发：quickshell ipc call shot area
        function area() {
            shotProc.exec(["sh", "-c", "grim -g \"$(slurp)\" - | wl-copy"])
        }
    }
}
