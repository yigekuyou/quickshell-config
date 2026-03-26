import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services
import Quickshell.Services.Pam
import qs.Config

Item {
    readonly property bool other: {
        return (Quickshell.env("QSG_RHI_BACKEND").toLowerCase() === "vulkan") === (WallpaperLock.wallpaperType === "scene");
    }

    Loader {
        id: lockLoader
        active: false
        source: "Lock.qml"
        Connections {
            enabled: lockLoader.status === Loader.Ready
            target: lockLoader.item
            function onUnlocked() {
                lockLoader.active = false;
            }
        }
    }
    IdleMonitor {
	    enabled: idlestatus
	    timeout: Config.general.idle.lockTimeout
	    onIsIdleChanged: {
		    if (isIdle)
			    root.lock.lock.locked = true;
	    }
    }
    Process {
        id: lock
        running: false
        command: ["qs", "--path", Quickshell.env("XDG_CONFIG_HOME") + "/quickshell/Wallpaper/Wall.qml", "ipc", "call", "lock", "open"]
    }
    IpcHandler {
        target: "lock"
        function open() {
            if (other) {
                lock.exec(lock.command);
		console.log("qs路径")
            } else {
                if (!lockLoader.active) {
                    lockLoader.active = true;
		    console.log("local路径")
                    return "LOCKED";
                }
                return "ALREADY_LOCKED";
            }
        }
    }
}
