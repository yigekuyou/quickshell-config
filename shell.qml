//@ pragma UseQApplication
import Quickshell
import Quickshell.Wayland
import Quickshell.Io  
import QtQuick        
import qs.Modules.Bar
import qs.Modules.DynamicIsland
import qs.Config
import qs.Modules.Launcher
import qs.Modules.Panel
import qs.Modules.Screenshot
import qs.Modules.Settings
import qs.Modules.Notifications
import qs.Wallpaper
ShellRoot {
	Screenshot {}
	NotificationPopupStack {}
	// 设置窗口：全屏遮罩 + 居中卡片（qs ipc call settings toggle）
	SettingsWindow {}
	LazyLoader {
		activeAsync:true
		Bar{}
	}
	Load{}
	Panel{}
}