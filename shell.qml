//@ pragma UseQApplication
import Quickshell
import Quickshell.Wayland
import Quickshell.Io  
import QtQuick        
import qs.Modules.Bar
import qs.Modules.DynamicIsland
import qs.config
import qs.Modules.Launcher

ShellRoot {
	Bar {}
	Variants {
	model: Quickshell.screens
	}

    // ================= 锁屏管理器 =================
    Loader {
        id: lockLoader
        active: false 
        
        source: "Modules/Lock/Lock.qml"
        
        Connections {
            target: lockLoader.item 
            ignoreUnknownSignals: true
            
            function onUnlocked() {
                lockLoader.active = false
            }
        }
    }
    IpcHandler {
        target: "lock" 
        
        function open() {
            if (!lockLoader.active) {
                lockLoader.active = true
                return "LOCKED"
            }
            return "ALREADY_LOCKED"
        }
    }
}
