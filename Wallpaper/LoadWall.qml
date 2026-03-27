import Quickshell
import Quickshell.Io
import QtQuick
import qs.Modules.Lock
import qs.Config
import qs.Modules.Wallpaper.WallpaperContent
import Quickshell.Wayland


Item {
	readonly property bool other: {
		return (Quickshell.env("QSG_RHI_BACKEND").toLowerCase() === "vulkan") === (WallpaperPath.wallpaperType === "scene");
	}
    Process {
        id: kded6
        running: true
        command: ["pkill", "kdekd6"]
    }
    LockManager{}

    Process {
        id: wallpaperProcess
        running: other
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
    LazyLoader {
	    id: wallLoader
	    activeAsync: !other
	    Wallpaper{}

    }
}
