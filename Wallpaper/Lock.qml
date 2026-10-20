import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import qs.Config
import qs.Services
import qs.Modules.Lock

ShellRoot {
	Lock{
		id:locked
		locked:false
		onUnlocked:{
			lock.exec(lock.command);
		}
	}
	Process {
		id: lock
		running: false
		command: ["qs", "--path", Directories.configDir + "/shell.qml", "ipc", "call", "lock", "close"]
	}
	IpcHandler {
		target: "lock"
		function open() {
				if (!locked.locked) {
					locked.locked = true;
					return "LOCKED";
				}
				return "ALREADY_LOCKED";
		}
	}
}

