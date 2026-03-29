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
	property bool expanded: false
	property bool warning: true
	headerOrientation: Qt.Horizontal
	Component.onCompleted: {
		switch (PowerProfiles.profile) {
			case PowerProfile.Performance:
				nowpower.source=performance.source
				break;
			case PowerProfile.PowerSaver:
				nowpower.source=powerSaver.source
				break;
			case PowerProfile.Balanced:
				nowpower.source=balanced.source
				break;
		}
		switch (PowerProfiles.degradationReason){
			case PerformanceDegradationReason.None:
			warning=false
			break;
		}
	}
	Connections {
		target: PowerProfiles
		function onProfileChanged() {
			switch (PowerProfiles.profile) {
				case PowerProfile.Performance:
					nowpower.source=performance.source
					break;
				case PowerProfile.PowerSaver:
					nowpower.source=powerSaver.source
					break;
				case PowerProfile.Balanced:
					nowpower.source=balanced.source
					break;
			}
		}

		// 当 degradationReason 属性改变时触发
		function onDegradationReasonChanged() {
			switch (PowerProfiles.degradationReason){
				case PerformanceDegradationReason.None:
					warning=false
					break;
				case PerformanceDegradationReason.LapDetected:
					warning=true
					break;
				case PerformanceDegradationReason.HighTemperature:
					warning=true
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
		NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutQuart }
	}
	HoverHandler {
		cursorShape: Qt.PointingHandCursor
	}
	TapHandler {
		acceptedButtons: Qt.LeftButton
		onTapped: {
			if(PowerProfiles.hasPerformanceProfile){
				expanded = !expanded
			}
		}
	}
	contentItem:RowLayout{
		id:layout
		layoutDirection: Qt.RightToLeft
		RowLayout{
			Kirigami.Icon {
				id:warn
				visible: warning //
				source:"emblem-warning"
				color:Kirigami.Theme.activeTextColor
				implicitHeight:Kirigami.Units.iconSizes.small
				implicitWidth: implicitHeight

			}
		}
		RowLayout{
			visible: !expanded //
			spacing: Kirigami.Units.smallSpacing
			Kirigami.Icon {
				id:nowpower
				color:Kirigami.Theme.activeTextColor
				implicitHeight:Kirigami.Units.iconSizes.small
			}
		}
		RowLayout{
			spacing: Kirigami.Units.smallSpacing
			visible: expanded //
			Kirigami.Icon {
				id:performance
				source:"power-profile-performance-symbolic"
				color:Kirigami.Theme.activeTextColor
				implicitHeight:Kirigami.Units.iconSizes.small
				implicitWidth: implicitHeight
				TapHandler {
					onTapped: {
						PowerProfiles.profile=PowerProfile.Performance
					}
				}
			}
		}
		RowLayout{
			visible: expanded //
			spacing: Kirigami.Units.smallSpacing
			Kirigami.Icon {
				id:balanced
				source:"power-profile-balanced-symbolic"
				color:Kirigami.Theme.activeTextColor
				implicitHeight:Kirigami.Units.iconSizes.small
				implicitWidth: implicitHeight
				TapHandler {
					onTapped: {
						PowerProfiles.profile=PowerProfile.Balanced
					}
				}
			}
		}
		RowLayout{
			visible: expanded //
			spacing: Kirigami.Units.smallSpacing
			Kirigami.Icon {
				id:powerSaver
				source:"power-profile-power-saver-symbolic"
				color:Kirigami.Theme.activeTextColor
				implicitHeight:Kirigami.Units.iconSizes.small
				implicitWidth: implicitHeight
				TapHandler {
					onTapped: {
						PowerProfiles.profile=PowerProfile.PowerSaver
					}
				}
			}
		}
	}

}
