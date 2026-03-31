import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Config
import Quickshell.Services.UPower
import org.kde.kirigami as Kirigami

Kirigami.AbstractCard {
    implicitHeight: Sizes.barHeight

    // ============================================================
    // 1. 属性定义
    // ============================================================
    property bool powerexpanded: false
    property bool warningexpanded: false
    property bool deviceexpanded: false
    property bool warning: true
    property var warningText: 0
    headerOrientation: Qt.Horizontal
    Component.onCompleted: {
        switch (PowerProfiles.profile) {
        case PowerProfile.Performance:
            nowpower.source = performance.source;
            break;
        case PowerProfile.PowerSaver:
            nowpower.source = powerSaver.source;
            break;
        case PowerProfile.Balanced:
            nowpower.source = balanced.source;
            break;
        }
        switch (PowerProfiles.degradationReason) {
        case PerformanceDegradationReason.None:
            warning = false;
            break;
        case PerformanceDegradationReason.LapDetected:
            warning = true;
            break;
        case PerformanceDegradationReason.HighTemperature:
            warning = true;
            break;
        }
    }
    Connections {
        target: PowerProfiles
        function onProfileChanged() {
            switch (PowerProfiles.profile) {
            case PowerProfile.Performance:
                nowpower.source = performance.source;
                break;
            case PowerProfile.PowerSaver:
                nowpower.source = powerSaver.source;
                break;
            case PowerProfile.Balanced:
                nowpower.source = balanced.source;
                break;
            }
        }

        // 当 degradationReason 属性改变时触发
        function onDegradationReasonChanged() {
            switch (PowerProfiles.degradationReason) {
            case PerformanceDegradationReason.None:
                warning = false;
		warningText=qsTr("无");
                break;
            case PerformanceDegradationReason.LapDetected:
                warning = true;
		warningText=qsTr("电量低");
		break;
            case PerformanceDegradationReason.HighTemperature:
                warning = true;
		warningText=qsTr("高温");
		break;
            }
        }
    }
    padding: Kirigami.Units.smallSpacing
    background: Kirigami.ShadowedRectangle {
        color: Kirigami.Theme.backgroundColor
        opacity: 0.5
        radius: Kirigami.Units.smallSpacing
        border.color: Kirigami.Theme.focusColor
        border.width: root.activeFocus ? 1 : 0
    }
    Behavior on implicitWidth {
        NumberAnimation {
            duration: Kirigami.Units.longDuration
            easing.type: Easing.OutQuart
        }
    }
    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
    contentItem: RowLayout {
        id: layout
        layoutDirection: Qt.RightToLeft
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignRight
        RowLayout {
            RowLayout {
                layoutDirection: Qt.RightToLeft
                anchors.right: parent.right
                Kirigami.Icon {
                    visible: UPower.displayDevice.ready
                    source: UPower.displayDevice.onBattery ? UPower.displayDevice.iconName : "ac-adapter-symbolic"
                    color: Kirigami.Theme.activeTextColor
                    implicitHeight: Kirigami.Units.iconSizes.small
                    implicitWidth: implicitHeight
                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        onTapped: {
                            if (PowerProfiles.hasPerformanceProfile) {
                                deviceexpanded = !deviceexpanded;
                            }
                        }
                    }
                }
                Kirigami.Icon {
                    id: warn
                    visible: warning //
                    source: "emblem-warning"
                    color: Kirigami.Theme.activeTextColor
                    implicitHeight: Kirigami.Units.iconSizes.small
                    implicitWidth: implicitHeight
                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        onTapped: {
                            if (PowerProfiles.hasPerformanceProfile) {
                                warningexpanded = !warningexpanded;
                            }
                        }
                    }
                }
                Kirigami.Icon {
                    id: nowpower
                    color: Kirigami.Theme.activeTextColor
                    implicitHeight: Kirigami.Units.iconSizes.small
                    implicitWidth: implicitHeight
                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        onTapped: {
                            if (PowerProfiles.hasPerformanceProfile) {
                                powerexpanded = !powerexpanded;
                            }
                        }
                    }
                }
                Kirigami.Separator {
                    implicitWidth: 1
                    Layout.fillHeight: true

                    // 2. 像素调节：上下留出一点边距，让视觉更精致
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                    Layout.leftMargin: Kirigami.Units.smallSpacing

                    // 3. 颜色：自动使用主题的分隔线颜色（带透明度，不突兀）
                    // 如果你想让它更亮或更暗，可以手动调节 opacity
                    opacity: 0.6
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Kirigami.Units.longDuration
                        }
                    }
                    // 4. 逻辑控制：如果你的音乐组件未展开，隐藏分割线
                    visible: root.powerexpanded
                }
            }
        }
        RowLayout {
            spacing: Kirigami.Units.smallSpacing
            visible: powerexpanded //
            layoutDirection: Qt.RightToLeft
            Kirigami.Icon {
                id: performance
                source: "power-profile-performance-symbolic"
                color: Kirigami.Theme.activeTextColor
                implicitHeight: Kirigami.Units.iconSizes.small
                implicitWidth: implicitHeight
                TapHandler {
                    onTapped: {
                        PowerProfiles.profile = PowerProfile.Performance;
                    }
                }
            }
            TapHandler {
                onTapped: {
                    PowerProfiles.profile = PowerProfile.Performance;
                }
            }
            Kirigami.Icon {
                id: balanced
                source: "power-profile-balanced-symbolic"
                color: Kirigami.Theme.activeTextColor
                implicitHeight: Kirigami.Units.iconSizes.small
                implicitWidth: implicitHeight
            }
            TapHandler {
                onTapped: {
                    PowerProfiles.profile = PowerProfile.Balanced;
                }
            }
            Kirigami.Icon {
                id: powerSaver
                source: "power-profile-power-saver-symbolic"
                color: Kirigami.Theme.activeTextColor
                implicitHeight: Kirigami.Units.iconSizes.small
                implicitWidth: implicitHeight
            }
            TapHandler {
                onTapped: {
                    PowerProfiles.profile = PowerProfile.PowerSaver;
                }
            }
        }
        RowLayout {
		spacing: Kirigami.Units.smallSpacing
		visible: warningexpanded //
		Kirigami.Heading{
			text:warningText
			level:5
		}
	}
	RowLayout {
		spacing: Kirigami.Units.smallSpacing
		visible: deviceexpanded //
		Repeater{
			model:UPower.devices
			delegate:RowLayout{
				Kirigami.Heading {
					id: devicename
					text:UPowerDeviceType.toString(modelData.type)
					level:5
					color: Kirigami.Theme.activeTextColor
				}
				Kirigami.Icon {
					id: devicepower
					source: modelData.isLaptopBattery ? modelData.iconName: "ac-adapter-symbolic"
					color: Kirigami.Theme.activeTextColor
					implicitHeight: Kirigami.Units.iconSizes.small
					implicitWidth: implicitHeight
				}
			}
		}
	}
    }
}
