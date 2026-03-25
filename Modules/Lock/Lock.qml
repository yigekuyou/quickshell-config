import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam

WlSessionLock {
	id: lock

	WlSessionLockSurface {
		Button {
			text: "unlock me"
			onClicked: lock.locked = false
		}
	}
}

// ...
lock.locked = true
