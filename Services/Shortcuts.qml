pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Services

// 全局快捷键的统一注册点。
//
// 注册方式按合成器条件加载（见下面的 isHyprland）：
//  - Hyprland：走 Quickshell 的 GlobalShortcut（hyprland_global_shortcuts_v1
//    协议），按键由合成器直接派发给本进程，不用像 `qs ipc call ...` 那样
//    每次按键都拉起一个 qs 子进程。Hyprland 侧配套绑定（见
//    ~/.config/hypr/hyprkeysbind.lua）：
//      hl.bind("SUPER + R", hl.dsp.global("quickshell:launcher-toggle"))
//    `global` 的参数是 `appid:name`：冒号前固定是 quickshell，冒号后是下面的 name。
//  - 其它合成器：没有注册路径。Qt 没有封装 xdg-desktop-portal 的
//    GlobalShortcuts（文档里只有窗口内的 QShortcut/QML Shortcut），
//    Quickshell 也明确不走 portal 协议（非 flatpak 下基本不可用），
//    所以这里不实例化任何注册器，只打一条警告。换了合成器的话，在对应的
//    按键处理代码（niri/sway 的 binds 等）里直接调下面的 trigger*() 即可。
//
// 对外只暴露信号 + trigger*()：订阅者（Panel/Screenshot/Load）不需要关心
// 按键的具体来源。协议不允许同一个 appid + name 重复注册，每个 name 只能出现一次。
Singleton {
	id: root

	// ==================== 对外接口 ====================
	signal launcherToggleRequested()
	signal screenshotRequested()
	signal screenshotInstantRequested()
	signal lockRequested()
	signal volumeMuteRequested()

	// 统一入口：Hyprland 的 GlobalShortcut、别的合成器按键处理、代码调用都从这几个函数进
	function triggerLauncherToggle() {
		root.launcherToggleRequested();
	}

	function triggerScreenshot() {
		root.screenshotRequested();
	}

	function triggerScreenshotInstant() {
		root.screenshotInstantRequested();
	}

	function triggerLock() {
		root.lockRequested();
	}

	function triggerVolumeMute() {
		root.volumeMuteRequested();
		Volume.toggleSinkMute();
	}

	// ==================== 合成器检测 ====================
	// Hyprland 运行时会给所有子进程设 HYPRLAND_INSTANCE_SIGNATURE；
	// 比读 XDG_CURRENT_DESKTOP 更可靠（那玩意可能被别的桌面残留污染）。
	// env 没设置时返回 null。
	readonly property bool isHyprland: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") !== null

	Component.onCompleted: {
		if (!root.isHyprland) {
			console.warn("[shortcuts] 当前合成器不是 Hyprland，全局快捷键未注册；" + "需要按键时请在外部处理逻辑里调用 Shortcuts.trigger*()");
		}
	}

	// ==================== Hyprland 注册实现（条件加载） ====================
	Loader {
		active: root.isHyprland
		sourceComponent: hyprlandShortcuts
	}

	Component {
		id: hyprlandShortcuts

		Item {
			GlobalShortcut {
				name: "launcher-toggle"
				description: "打开 / 关闭应用启动器"
				onPressed: root.triggerLauncherToggle()
			}

			GlobalShortcut {
				name: "screenshot"
				description: "打开截图界面（复制 / 保存 / 区域 / 全屏）"
				onPressed: root.triggerScreenshot()
			}

			GlobalShortcut {
				name: "screenshot-instant"
				description: "整屏截图并直接复制到剪贴板"
				onPressed: root.triggerScreenshotInstant()
			}

			GlobalShortcut {
				name: "lock"
				description: "锁定屏幕"
				onPressed: root.triggerLock()
			}

			GlobalShortcut {
				name: "volume-mute"
				description: "切换默认音频输出的静音状态"
				onPressed: root.triggerVolumeMute()
			}
		}
	}
}
