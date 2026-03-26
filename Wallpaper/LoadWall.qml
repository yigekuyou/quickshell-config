import Quickshell
import Quickshell.Io
import QtQuick
Item{
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
		"DRI_PRIME": "1",
		"QSG_RHI_BACKEND": "opengl"
	})


        stdout: StdioCollector {
		onStreamFinished: console.log(`Wallpaper Process Output: ${this.text}`)
	}
    }
    Process {
	    id: lock
	    running: false

	    // 修复点：将 "ipc call lock open" 拆分为独立的参数
	    command: [
		    "qs",
		    "--path",
		    Quickshell.env("XDG_CONFIG_HOME") + "/quickshell/Wallpaper/Wall.qml",
		    "ipc",
		    "call",
		    "lock",
		    "open"
	    ]

	    stdout: StdioCollector {
		    // 注意：根据文档，StdioCollector 的属性通常是 'text'
		    // 使用 onStreamFinished 触发时，确保逻辑正确
		    onStreamFinished: console.log(`lock Output: ${this.text}`)
	    }
    }
    IpcHandler {
	    target: "lock"
	    function open() {
		    lock.exec(lock.command);
	    }
    }
}
