import Quickshell
import Quickshell.Io
import QtQuick
import qs.Modules.Lock
import qs.Config
import qs.Services
import qs.Modules.Wallpaper.WallpaperContent
import Quickshell.Wayland
import Quickshell.Hyprland
Scope {
	id: root
	property bool lockLoader: false
		readonly property bool other: {
		return (Quickshell.env("QSG_RHI_BACKEND").toLowerCase() === "vulkan") === (WallpaperPath.wallpaperType === "scene");
	}
	readonly property bool opengl: {
		return (Quickshell.env("QSG_RHI_BACKEND").toLowerCase() === "vulkan") === (WallpaperLock.wallpaperType === "scene");
	}
	IdleMonitor {
		enabled: Idle.idledpms && (lockLoader)
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
		enabled: Idle.idlelock && !lockLoader &&(Lyrics.player?(false):true)
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
		id: lock
		running: false
		command: ["qs", "--path", Directories.configDir + "/Wallpaper/Lock.qml", "ipc", "call", "lock", "open"]
	}
	// 锁屏入口：全局快捷键 quickshell:lock 和 IPC (qs ipc call lock open) 都走这里
	function lockNow() {
		lock.startDetached();
		lockLoader = true;
	}

	IpcHandler {
		target: "lock"
		function open() {
			root.lockNow();
		}
		function close(){
			lockLoader=false
		}
	}

	// 全局快捷键 quickshell:lock，由 Services/Shortcuts.qml 注册
	Connections {
		target: Shortcuts

		function onLockRequested() {
			root.lockNow();
		}
	}
	LazyLoader {
		id: vkLoader
		activeAsync:!opengl
		Process {
			id: vulkanProcess
			running: true
			// 1. 设置执行文件路径
			command: ["qs", "--path", Directories.configDir + "/Wallpaper/Lock.qml"]
			environment: ({
				"QSLOCK": "1",
				"QS_APP_ID":"org.quickshell.lock"
			})
		}

	}
	LazyLoader {
		id: glLoader
		activeAsync:opengl
		Process {
			id: opengllockProcess
			running: true
			// 1. 设置执行文件路径
			command: ["qs", "--path", Directories.configDir + "/Wallpaper/Lock.qml"]
			// 3. 设置环境变量
			environment: ({
				"QSLOCK": "1",
				"QS_APP_ID":"org.quickshell.lock",
				"DRI_PRIME": "1",
				"QSG_RHI_BACKEND": "opengl"
			})
		}
	}
    Process {
        id: kded6
        running: true
        command: ["pkill", "kdekd6"]
    }

    LazyLoader {
	    id: wallLoader
	    activeAsync: !other
	    Wallpaper{}
    }

    LazyLoader {
	    activeAsync: true
    }
    LazyLoader {
	    id: wallpaper
	    activeAsync: other
	    Process {
		    id: wallpaperProcess
		    running: true
		    // 1. 设置执行文件路径
		    command: ["qs", "--path", Directories.configDir + "/Wallpaper/Wall.qml"]
		    // 3. 设置环境变量
		    environment: ({
			    "DRI_PRIME": "1",
			    "QS_APP_ID":"org.quickshell.wall",
			    "QSG_RHI_BACKEND": "opengl",
			    // 标记这是 scene 专用子进程：它只负责场景渲染，
			    // 不要在里面对 Web 壁纸再起一个 WebEngine 子进程
			    "QS_WALLPAPER_SCENE_CHILD": "1"
		    })
		    // 切到 video/web 时 LazyLoader 会销毁这个 Process 对象，
		    // 但子 qs 不一定跟着退出；按 pid 显式清理，避免留下孤儿背景层
		    Component.onDestruction: {
			    if (running && processId)
				    Quickshell.execDetached(["kill", String(processId)]);
		    }
	    }
    }
}
