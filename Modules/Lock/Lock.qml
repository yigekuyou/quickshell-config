import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Config

ShellRoot {
	signal unlocked()
	property QtObject pamBackend

	IdleMonitor {
		enabled: Idle.idledpms
		timeout: Idle.dpmsTimeout
		onIsIdleChanged: {
			if (isIdle)
				Hypr.dispatch("dpms off");
			else
				Hypr.dispatch("dpms on");
		}
	}

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
