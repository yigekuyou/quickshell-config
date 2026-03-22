pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root
    readonly property string day: {
	Qt.formatDateTime(clock.date, "dd");
    }
    readonly property string week:{
	Qt.formatDateTime(clock.date, "dddd")
    }
    readonly property string month: {
	Qt.formatDateTime(clock.date, "MMMM");
    }
    readonly property string year:{
	Qt.formatDateTime(clock.date, "yyyy")
    }
    readonly property string hours: {
	Qt.formatDateTime(clock.date, "hh");
    }
    readonly property string minutes: {
	Qt.formatDateTime(clock.date, "mm");
    }
    readonly property string amPm:{
	Qt.formatDateTime(clock.date, "AP")
    }
    SystemClock {
	id: clock
	precision: SystemClock.Minutes
    }
}
