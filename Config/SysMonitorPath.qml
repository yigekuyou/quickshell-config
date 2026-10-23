pragma Singleton
import QtQuick
Item{
	// CPU 核心温度：hwmon 编号会漂移，认准 name=k10temp（AMD CPU 传感器）。
	// 旧值 hwmon3 其实是 amdgpu 卡（0000:03:00.0）的温度，不是 CPU。
	readonly property string cpuhwmon :"/sys/class/hwmon/hwmon5/temp1_input"

	// GPU：驱动显示的那张卡（card2 = 0000:08:00.0，HDMI-A-2 接显示器）
	// hwmon 编号会随内核版本 / 启动顺序漂移，漂了只改这里一处
	readonly property string gpuBusy: "/sys/class/drm/card2/device/gpu_busy_percent"
	readonly property string gpuPower: "/sys/class/drm/card2/device/hwmon/hwmon4/power1_input"
}
