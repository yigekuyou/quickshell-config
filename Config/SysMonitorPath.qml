pragma Singleton
import QtQuick
Item{
	readonly property string cpuhwmon :"/sys/class/hwmon/hwmon3/temp1_input"
}
