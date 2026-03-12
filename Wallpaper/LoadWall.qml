import Quickshell
import Quickshell.Io
import QtQuick
    Process {
        id: wallpaperProcess
        running: true
        // 1. 设置执行文件路径
        command: [
		"qs",
		"--path",
		Quickshell.env("XDG_CONFIG_HOME") + "/quickshell/Wallpaper/Wall.qml"
	]
        // 3. 设置环境变量
        environment: ({
		"DRI_PRIME": "pci-0000_03_00_0",
		"QSG_RHI_BACKEND": "opengl"
	})


        stdout: StdioCollector {
		onStreamFinished: console.log(`Wallpaper Process Output: ${this.text}`)
	}
    }
