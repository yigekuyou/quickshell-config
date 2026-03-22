pragma Singleton

import Quickshell
import QtQuick

Singleton {
    property var locale: Qt.locale()
    readonly property string day: clock.date.toLocaleString(locale, "dd")
    readonly property string week: clock.date.toLocaleString(locale, "dddd")
    readonly property string month: clock.date.toLocaleString(locale, "MMMM")
    readonly property string year: clock.date.toLocaleString(locale, "yyyy")
    readonly property string hours: clock.date.toLocaleString(locale, "hh")
    readonly property string minutes: clock.date.toLocaleString(locale, "mm")
    readonly property string amPm: clock.date.toLocaleString(locale, "AP")
    SystemClock {
	id: clock
	precision: SystemClock.Minutes
    }
}
