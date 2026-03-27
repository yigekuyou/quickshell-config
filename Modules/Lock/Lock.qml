import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Config
import Quickshell.Hyprland


WlSessionLock {
	signal unlocked()
	locked : true
	onLockedChanged: {
		if (!locked) {
			unlocked();
		}
	}
	WlSessionLockSurface {
		LockSurface{
			onUnlocked: locked = false
		}
	}
}

