import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.Services
import Quickshell.Services.Pam
import qs.Config
import Quickshell.Hyprland

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
        enabled: Idle.idledpms && (lockLoader.status === Loader.Ready) && lockLoader.item.locked
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
        enabled: Idle.idlelock && !(lockLoader.status === Loader.Ready) && !other
        timeout: Idle.idlelocktime
        onIsIdleChanged: {
            if (isIdle) {
                    if (!lockLoader.active) {
                        lockLoader.active = true;
                        return "LOCKED";
                    }
                    return "ALREADY_LOCKED";
            }
        }
    }
    IdleMonitor {
        enabled: Idle.idlesleep&&lockLoader.active
        timeout: Idle.sleepTimeout
        onIsIdleChanged: {
            if (isIdle)
                Quickshell.execDetached(["systemctl", "suspend"]);
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
            } else {
                if (!lockLoader.active) {
                    lockLoader.active = true;
                    return "LOCKED";
                }
                return "ALREADY_LOCKED";
            }
        }
    }
}
