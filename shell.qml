 //@ pragma UseQApplication
import Quickshell
import Quickshell.Wayland
import Quickshell.Io  
import QtQuick        
import qs.Modules.Bar
import qs.Modules.DynamicIsland
import qs.config
import qs.Modules.Launcher
import qs.Modules.Panel
import qs.Wallpaper
ShellRoot {
	Variants {model: Quickshell.screens
	}
	Bar {}
	LoadWall{}
	Panel{}
}
