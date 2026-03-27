import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Config
import Quickshell.Hyprland

ShellRoot {
	id: root
	signal unlocked()
	property QtObject pamBackend



WlSessionLock {
	id: lock
	locked : true
	onLockedChanged: {
		if (!locked) {
			root.unlocked();
		}
	}
	WlSessionLockSurface {
		LockSurface{
			onUnlocked: lock.locked = false
		}
	}
}
}
