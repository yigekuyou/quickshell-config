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

	// ------------------------------------------------------------------
	// 启动清扫：上一轮 qs 如果是被 OOM/崩溃杀掉的，它起的 Web 壁纸进程
	// （qml6 Wallpaper/Web.qml）可能还留在背景层上，而且可能停在 T（被
	// SIGSTOP 冻结）状态 —— 冻结的进程收不到 SIGTERM，也不会自己退出，
	// 于是新实例会和它抢同一个图层（实测同时跑过 3 个 WebEngine）。
	//
	// 这里在启动时把"不是本次 qs 生的"同款进程先 CONT 再 KILL 掉：
	//   * 只认 cmdline 同时含 qml6 和 Wallpaper/Web.qml 的进程，别的 qml6 不动；
	//   * ppid 等于本 qs（$PPID 就是起这个 sh 的 qs）的一律跳过，
	//     避免把我们自己刚起的子进程误杀。
	// ------------------------------------------------------------------
	Process {
		id: staleSweep
		running: false
		command: ["sh", "-c",
			'for p in $(pgrep -f "Wallpaper/Web.qml" 2>/dev/null); do '
			+ '[ "$(ps -o ppid= -p $p 2>/dev/null | tr -d " ")" = "$PPID" ] && continue; '
			+ '[ "$(cat /proc/$p/comm 2>/dev/null)" = qml6 ] || continue; '
			+ 'grep -qa Wallpaper/Web.qml /proc/$p/cmdline 2>/dev/null || continue; '
			+ 'kill -CONT $p 2>/dev/null; kill -KILL $p 2>/dev/null; '
			+ 'done; true']
	}
	Component.onCompleted: staleSweep.running = true
}