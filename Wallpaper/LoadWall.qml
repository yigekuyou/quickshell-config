import Quickshell
import Quickshell.Io
import QtQuick
import qs.Modules.Lock
import qs.Config
import qs.Modules.Wallpaper.WallpaperContent
import Quickshell.Wayland


Scope {
	readonly property bool other: {
		return (Quickshell.env("QSG_RHI_BACKEND").toLowerCase() === "vulkan") === (WallpaperPath.wallpaperType === "scene");
	}
    Process {
        id: kded6
        running: false
        command: ["pkill", "kdekd6"]
    }

    LazyLoader {
	    id: wallLoader
	    activeAsync: !other
	    Wallpaper{}

    }
    LazyLoader {
	    id: wallpaper
	    activeAsync: !other
	    Process {
		    id: wallpaperProcess
		    running: false
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
}
