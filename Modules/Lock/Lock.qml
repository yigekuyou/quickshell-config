import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
	property var pam:LockManager.pam
	signal unlocked()

	id: root
	Timer {
		id: safetyTimer
		interval: 5000
		running: true
		repeat: false
		onTriggered: {
			lock.locked = false
		}
	}
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
		}
	}
}
}
