pragma Singleton
import Quickshell
import Quickshell.Wayland
Singleton{
	property bool idlestatus: true

	IdleMonitor {
		enabled: idlestatus
		timeout: Config.general.idle.sleepTimeout
		onIsIdleChanged: {
			if (isIdle)
				Quickshell.execDetached(["systemctl", "suspend-then-hibernate"]);
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

	IdleMonitor {
		enabled: root.enabled
		timeout: Config.general.idle.dpmsTimeout
		onIsIdleChanged: {
			if (isIdle)
				Hypr.dispatch("dpms off");
			else
				Hypr.dispatch("dpms on");
		}
	}
}
