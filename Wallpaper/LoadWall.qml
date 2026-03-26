import Quickshell
import Quickshell.Io
import QtQuick

Item {
    Process {
        id: kded6
        running: true
        command: ["pkill", "kdekd6"]
    }
    Process {
        id: wallpaperProcess
        running: true
        // 1. 设置执行文件路径
        command: ["qs", "--path", Quickshell.env("XDG_CONFIG_HOME") + "/quickshell/Wallpaper/Wall.qml"]
        // 3. 设置环境变量
        environment: ({
                "DRI_PRIME": "1",
                "QSG_RHI_BACKEND": "opengl"
            })
        stdout: StdioCollector {
            onStreamFinished: console.log(`Wallpaper Process Output: ${this.text}`)
        }
    }
}
