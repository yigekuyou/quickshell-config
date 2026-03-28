import Quickshell
import Quickshell.Io
import Quickshell
import QtQuick
import qs.Modules.Lock
import qs.Config
import qs.Modules.Wallpaper.WallpaperContent
import Quickshell.Wayland


Scope {
	readonly property bool lockLoader: false
	readonly property bool opengl: {
		return (Quickshell.env("QSG_RHI_BACKEND").toLowerCase() === "vulkan") === (WallpaperLock.wallpaperType === "scene");
	}
	IdleMonitor {
		enabled: Idle.idledpms && (lockLoader) && lockLoader.item.locked
		timeout: Idle.dpmsTimeout
		onIsIdleChanged: {
			if (isIdle)
				Hyprland.dispatch("dpms off");
		}
	}
	IdleMonitor {
		enabled: Idle.idledpms
		timeout: Idle.dpmsTimeout+Idle.idlelocktime
		onIsIdleChanged: {
			if (!isIdle)
				Hyprland.dispatch("dpms on");
		}
	}
	IdleMonitor {
		enabled: Idle.idlelock && !lockLoader && !other
		timeout: Idle.idlelocktime
		onIsIdleChanged: {
			if (isIdle) {
				if (!lockLoader) {
					lockLoader = true;
					lock.exec(lock.command);
					return "LOCKED";
				}
				return "ALREADY_LOCKED";
			}
		}
	}
	IdleMonitor {
		enabled: Idle.idlesleep&&lockLoader
		timeout: Idle.sleepTimeout
		onIsIdleChanged: {
			if (isIdle)
				Quickshell.execDetached(["systemctl", "suspend"]);
		}
	}
    Process {
        id: opengllockProcess
        running: opengl
        // 1. 设置执行文件路径
        command: ["qs", "--path", Quickshell.env("XDG_CONFIG_HOME") + "/quickshell/Wallpaper/Lock.qml"]
        // 3. 设置环境变量
        environment: ({
		"QSLOCK": "1",
                "DRI_PRIME": "1",
                "QSG_RHI_BACKEND": "opengl"
            })
        stdout: StdioCollector {
            onStreamFinished: console.log(`lock Process Output: ${this.text}`)
        }
    }
    Process {
	    id: vulkanProcess
	    running: !opengl
	    // 1. 设置执行文件路径
	    command: ["qs", "--path", Quickshell.env("XDG_CONFIG_HOME") + "/quickshell/Wallpaper/Lock.qml"]
	    environment: ({
		    "QSLOCK": "1"
	    })
	    stdout: StdioCollector {
		    onStreamFinished: console.log(`lock Process Output: ${this.text}`)
	    }
    }
    Process {
	    id: lock
	    running: false
	    command: ["qs", "--path", Quickshell.env("XDG_CONFIG_HOME") + "/quickshell/Wallpaper/Lock.qml", "ipc", "call", "lock", "open"]
    }
    IpcHandler {
	    target: "lock"
	    function open() {
	    lock.exec(lock.command);
	    lockLoader=true
	    }
	    function close(){
		    lockLoader=false

	}
    }
}
