import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
	signal unlocked()
	property QtObject pamBackend

	id: root
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
