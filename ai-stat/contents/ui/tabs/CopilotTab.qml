import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

import "../../code/formatters.js" as Api
import "../charts"
import "../components"

Flickable {
    id: copilotTab

    required property var appRoot

    contentWidth: width
    contentHeight: copilotCol.implicitHeight + Kirigami.Units.largeSpacing
    clip: true
    flickableDirection: Flickable.VerticalFlick
    QQC2.ScrollBar.vertical: QQC2.ScrollBar { id: scrollBar; policy: QQC2.ScrollBar.AsNeeded }

    ColumnLayout {
        id: copilotCol
        width: parent.width - Kirigami.Units.smallSpacing - (scrollBar.visible ? scrollBar.width : 0)
        spacing: Kirigami.Units.mediumSpacing

        // Header
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                text: "GitHub Copilot CLI" + (appRoot.copilotUser ? " · " + appRoot.copilotUser : "")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.5
                Layout.fillWidth: true
            }
            Item { Layout.fillWidth: true }

            PlasmaComponents.Label {
                text: appRoot.copilotLastFetchedMs > 0
                      ? i18n("Fetched %1", new Date(appRoot.copilotLastFetchedMs).toLocaleTimeString(Qt.locale(), Locale.ShortFormat))
                      : i18n("Fetched --")
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.92
                opacity: 0.45
            }

            QQC2.BusyIndicator {
                running: appRoot.copilotLoading; visible: appRoot.copilotLoading
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
            QQC2.ToolButton { icon.name: "view-refresh"; onClicked: appRoot.refreshAll() }
        }

        // Dashboard meters (standardized centered 3-meter row; always single-line)
        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            Item {
                id: copilotDashboardTop
                Layout.fillWidth: true
                implicitHeight: copilotMetersRow.implicitHeight
                property real _spacing: Kirigami.Units.smallSpacing
                property real _targetRing: Kirigami.Units.gridUnit * (appRoot.onDesktop ? 6 : 5.6)
                property real _targetTacho: Kirigami.Units.gridUnit * (appRoot.onDesktop ? 10 : 8.8)
                property real _needed: (_targetRing * 2) + _targetTacho + (_spacing * 2)
                property real _scale: Math.min(1, Math.max(0.5, (width - Kirigami.Units.smallSpacing) / Math.max(_needed, 1)))
                property real _ringSize: _targetRing * _scale
                property real _tachoW: _targetTacho * _scale

                Row {
                    id: copilotMetersRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: copilotDashboardTop._spacing * copilotDashboardTop._scale

                    // Turns meter (left)
                    Column {
                        width: copilotDashboardTop._ringSize
                        spacing: 2
                        DualQuotaRing {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: copilotDashboardTop._ringSize
                            height: copilotDashboardTop._ringSize
                            outerUsed: appRoot.copilotTurnsToday
                            outerLimit: Math.max(appRoot.copilotTurnsWeek, Math.round(appRoot.copilotTurnsMonth / 4), appRoot.copilotTurnsToday * 1.5, 1)
                            outerLabel: "day"
                            outerColor: Kirigami.Theme.highlightColor
                            innerUsed: appRoot.copilotTurnsWeek
                            innerLimit: Math.max(appRoot.copilotTurnsMonth, appRoot.copilotTurnsWeek * 1.2, 1)
                            innerLabel: "week"
                            innerColor: Kirigami.Theme.positiveTextColor
                        }
                        PlasmaComponents.Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: i18n("Turns")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                            opacity: 0.35
                        }
                    }

                    // Activity meter (center)
                    Column {
                        width: copilotDashboardTop._tachoW
                        spacing: 2
                        Tachometer {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: copilotDashboardTop._tachoW
                            height: copilotDashboardTop._tachoW * 0.72
                            value: appRoot.copilotTurnsToday
                            avgValue: Math.max(1, appRoot.copilotTurnsWeek / 7)
                            maxValue: Math.max(10, appRoot.copilotTurnsWeek, Math.round(appRoot.copilotTurnsMonth / 2))
                            label: i18n("turns/day")
                            innerValue: appRoot.copilotSessionsToday
                            innerMaxValue: Math.max(1, appRoot.copilotSessionsWeek)
                            activityLevel: appRoot.copilotSessionsActive > 0 ? 1 : 0
                        }
                        PlasmaComponents.Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: i18n("Activity")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                            opacity: 0.35
                        }
                    }

                    // Session meter (right)
                    Column {
                        width: copilotDashboardTop._ringSize
                        spacing: 2
                        DualQuotaRing {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: copilotDashboardTop._ringSize
                            height: copilotDashboardTop._ringSize
                            outerUsed: appRoot.copilotSessionsToday
                            outerLimit: Math.max(appRoot.copilotSessionsWeek, appRoot.copilotSessionsToday * 1.5, 1)
                            outerLabel: "day"
                            outerColor: Kirigami.Theme.highlightColor
                            innerUsed: appRoot.copilotSessionsActive
                            innerLimit: Math.max(1, appRoot.copilotSessionsToday)
                            innerLabel: "act"
                            innerColor: Kirigami.Theme.positiveTextColor
                        }
                        PlasmaComponents.Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: i18n("Sessions")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                            opacity: 0.35
                        }
                    }
                }
            }
        }

        // Stats
        ColumnLayout {
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("Prompt Stats") }
            GridLayout {
                Layout.fillWidth: true
                columns: 3; columnSpacing: Kirigami.Units.smallSpacing; rowSpacing: Kirigami.Units.smallSpacing
                StatCard { label: i18n("Today"); value: appRoot.copilotTurnsToday.toString(); accent: Kirigami.Theme.highlightColor; Layout.fillWidth: true }
                StatCard { label: i18n("Week"); value: appRoot.copilotTurnsWeek.toString(); accent: Kirigami.Theme.positiveTextColor; Layout.fillWidth: true }
                StatCard { label: i18n("Month"); value: appRoot.copilotTurnsMonth.toString(); accent: Kirigami.Theme.neutralTextColor; Layout.fillWidth: true }
            }
        }

        // Sessions
        ColumnLayout {
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("Session Stats") }
            GridLayout {
                Layout.fillWidth: true
                columns: 4; columnSpacing: Kirigami.Units.smallSpacing; rowSpacing: Kirigami.Units.smallSpacing
                StatCard { label: i18n("Today"); value: appRoot.copilotSessionsToday.toString(); accent: Kirigami.Theme.highlightColor; Layout.fillWidth: true }
                StatCard { label: i18n("Week"); value: appRoot.copilotSessionsWeek.toString(); accent: Kirigami.Theme.positiveTextColor; Layout.fillWidth: true }
                StatCard { label: i18n("Month"); value: appRoot.copilotSessionsMonth.toString(); accent: Kirigami.Theme.neutralTextColor; Layout.fillWidth: true }
                StatCard { label: i18n("Total"); value: appRoot.copilotSessionsTotal.toString(); accent: Kirigami.Theme.textColor; Layout.fillWidth: true }
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 1
                StatCard {
                    label: i18n("Active Sessions")
                    value: appRoot.copilotSessionsActive.toString()
                    accent: appRoot.copilotSessionsActive > 0 ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor
                    Layout.fillWidth: true
                }
            }
        }

        // 12h History
        Item {
            visible: appRoot.copilotFineTurns.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: appRoot.onDesktop ? Kirigami.Units.gridUnit * 8 : Kirigami.Units.gridUnit * 6
            Layout.margins: Kirigami.Units.smallSpacing
            ColumnLayout {
                anchors.fill: parent; spacing: Kirigami.Units.smallSpacing
                SectionHeader { text: i18n("12h") }
                HourlyChart { Layout.fillWidth: true; Layout.fillHeight: true; rawData: appRoot.copilotFineTurns; bucketMinutes: 5 }
            }
        }

        // Daily History
        Item {
            id: copilotDailySection
            visible: appRoot.copilotDailyTurns.length > 0
            property var _chartData: {
                var raw = appRoot.copilotDailyTurns || []
                var out = []
                for (var i = 0; i < raw.length; i++) {
                    out.push({
                        day: raw[i].day || "",
                        input: Number(raw[i].turns || 0),
                        output: 0
                    })
                }
                return out
            }
            Layout.fillWidth: true
            Layout.preferredHeight: appRoot.onDesktop ? Kirigami.Units.gridUnit * 8 : Kirigami.Units.gridUnit * 6
            Layout.margins: Kirigami.Units.smallSpacing
            ColumnLayout {
                anchors.fill: parent; spacing: Kirigami.Units.smallSpacing
                SectionHeader { text: i18n("Daily History") }
                DailyChart { Layout.fillWidth: true; Layout.fillHeight: true; chartData: copilotDailySection._chartData }
            }
        }

        // Recent Sessions
        ColumnLayout {
            visible: appRoot.copilotRecentSessions.length > 0
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("Recent Sessions") }

            Repeater {
                model: appRoot.copilotRecentSessions

                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: sessCol.implicitHeight + Kirigami.Units.smallSpacing * 2
                    radius: Kirigami.Units.cornerRadius
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.03)

                    ColumnLayout {
                        id: sessCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Kirigami.Units.smallSpacing }
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            PlasmaComponents.Label {
                                text: modelData.project || modelData.id || ""
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                font.weight: Font.DemiBold
                                Layout.fillWidth: true
                            }
                            PlasmaComponents.Label {
                                text: Api.formatDuration(modelData.duration_min || 0)
                                visible: (modelData.duration_min || 0) > 0
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                opacity: 0.4
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            PlasmaComponents.Label {
                                text: (modelData.turns || 0) + " turns"
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                color: Kirigami.Theme.highlightColor
                            }
                            PlasmaComponents.Label {
                                text: modelData.model || ""
                                visible: (modelData.model || "") !== ""
                                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.95
                                opacity: 0.35
                            }
                            Item { Layout.fillWidth: true }
                            PlasmaComponents.Label {
                                text: {
                                    var ts = modelData.timestamp || ""
                                    if (!ts) return ""
                                    var d = new Date(ts)
                                    var now = new Date()
                                    var diff = now - d
                                    if (diff < 3600000) return Math.max(1, Math.round(diff / 60000)) + "m ago"
                                    if (diff < 86400000) return Math.round(diff / 3600000) + "h ago"
                                    return Math.round(diff / 86400000) + "d ago"
                                }
                                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.95
                                opacity: 0.35
                            }
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
