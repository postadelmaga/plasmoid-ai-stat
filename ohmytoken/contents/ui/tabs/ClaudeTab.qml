import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

import "../../code/formatters.js" as Api
import "../charts"
import "../components"

Flickable {
    id: claudeTab

    // All state comes from the root PlasmoidItem
    required property var appRoot

    contentWidth: width
    contentHeight: claudeCol.implicitHeight + Kirigami.Units.largeSpacing
    clip: true
    flickableDirection: Flickable.VerticalFlick
    QQC2.ScrollBar.vertical: QQC2.ScrollBar { id: scrollBar; policy: QQC2.ScrollBar.AsNeeded }

    ColumnLayout {
        id: claudeCol
        width: parent.width - Kirigami.Units.smallSpacing - (scrollBar.visible ? scrollBar.width : 0)
        spacing: Kirigami.Units.mediumSpacing

        // Header
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                text: {
                    var plan = appRoot.subType.charAt(0).toUpperCase() + appRoot.subType.slice(1)
                    var parts = [plan]
                    if (appRoot.tierName) parts.push(appRoot.tierName)
                    return parts.join(" \u00b7 ")
                }
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.5
                Layout.fillWidth: true
            }
            Item { Layout.fillWidth: true }

            // Active sessions indicator
            RowLayout {
                visible: appRoot.activeSessions > 0
                spacing: Kirigami.Units.smallSpacing / 2

                Rectangle {
                    width: 7; height: 7; radius: 3.5
                    color: Kirigami.Theme.positiveTextColor
                }
                PlasmaComponents.Label {
                    text: appRoot.activeSessions + " active"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    color: Kirigami.Theme.positiveTextColor
                    opacity: 0.7
                }
            }

            PlasmaComponents.Label {
                text: appRoot.claudeLastFetchedMs > 0
                      ? i18n("Fetched %1", new Date(appRoot.claudeLastFetchedMs).toLocaleTimeString(Qt.locale(), Locale.ShortFormat))
                      : i18n("Fetched --")
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.92
                opacity: 0.45
            }

            QQC2.BusyIndicator {
                running: appRoot.loading; visible: appRoot.loading
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
            QQC2.ToolButton { icon.name: "view-refresh"; onClicked: appRoot.refreshAll() }
        }

        // ── Dashboard (standardized centered 3-meter row; always single-line) ──
        ColumnLayout {
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            Item {
                id: dashboardTop
                Layout.fillWidth: true
                implicitHeight: meterRow.implicitHeight
                property real _spacing: Kirigami.Units.smallSpacing
                property real _targetRing: Kirigami.Units.gridUnit * (appRoot.onDesktop ? 6 : 5.6)
                property real _targetTacho: Kirigami.Units.gridUnit * (appRoot.onDesktop ? 10 : 8.8)
                property real _needed: (_targetRing * 2) + _targetTacho + (_spacing * 2)
                property real _scale: Math.min(1, Math.max(0.5, (width - Kirigami.Units.smallSpacing) / Math.max(_needed, 1)))
                property real _ringSize: _targetRing * _scale
                property real _tachoW: _targetTacho * _scale
                readonly property real _sessionInLimit: appRoot.sessionInputLimit > 0
                                                       ? appRoot.sessionInputLimit
                                                       : Math.max(appRoot.limInTokPerDay > 0 ? appRoot.limInTokPerDay / 5 : appRoot.tokInToday * 1.25, 1)
                readonly property real _sessionOutLimit: appRoot.sessionOutputLimit > 0
                                                        ? appRoot.sessionOutputLimit
                                                        : Math.max(appRoot.limOutTokPerDay > 0 ? appRoot.limOutTokPerDay / 5 : appRoot.tokOutToday * 1.25, 1)
                readonly property real _sessionInUsed: appRoot.sessionInputUsed > 0
                                                       ? appRoot.sessionInputUsed
                                                       : Math.max(0, appRoot.tokInToday > 0 ? appRoot.tokInToday / 5 : (appRoot.tokInWeek > 0 ? appRoot.tokInWeek / 35 : 0))
                readonly property real _sessionOutUsed: appRoot.sessionOutputUsed > 0
                                                        ? appRoot.sessionOutputUsed
                                                        : Math.max(0, appRoot.tokOutToday > 0 ? appRoot.tokOutToday / 5 : (appRoot.tokOutWeek > 0 ? appRoot.tokOutWeek / 35 : 0))
                readonly property real _dailyInLimit: appRoot.limInTokPerDay > 0
                                                     ? appRoot.limInTokPerDay
                                                     : Math.max(appRoot.tokInToday * 1.25, appRoot.tokInWeek > 0 ? appRoot.tokInWeek / 7 : 0, 1)
                readonly property real _dailyOutLimit: appRoot.limOutTokPerDay > 0
                                                      ? appRoot.limOutTokPerDay
                                                      : Math.max(appRoot.tokOutToday * 1.25, appRoot.tokOutWeek > 0 ? appRoot.tokOutWeek / 7 : 0, 1)
                readonly property real _dailyInUsed: appRoot.tokInToday > 0
                                                     ? appRoot.tokInToday
                                                     : Math.max(0, appRoot.tokInWeek > 0 ? appRoot.tokInWeek / 7 : 0)
                readonly property real _dailyOutUsed: appRoot.tokOutToday > 0
                                                      ? appRoot.tokOutToday
                                                      : Math.max(0, appRoot.tokOutWeek > 0 ? appRoot.tokOutWeek / 7 : 0)
                readonly property bool _usingDailyFallback: appRoot.tokInToday <= 0 && appRoot.tokOutToday <= 0
                                                            && (appRoot.tokInWeek > 0 || appRoot.tokOutWeek > 0)
                readonly property bool _usingSessionFallback: appRoot.sessionInputUsed <= 0 && appRoot.sessionOutputUsed <= 0
                                                              && (_sessionInUsed > 0 || _sessionOutUsed > 0)
                readonly property real _lastFineAllPerHour: {
                    var series = appRoot.fineTokens || []
                    for (var i = series.length - 1; i >= 0; --i) {
                        var total = (series[i].input || 0) + (series[i].output || 0)
                        if (total > 0) return total * 12
                    }
                    return 0
                }
                readonly property real _lastFineOutPerHour: {
                    var series = appRoot.fineTokens || []
                    for (var i = series.length - 1; i >= 0; --i) {
                        var out = series[i].output || 0
                        if (out > 0) return out * 12
                    }
                    return 0
                }

                Row {
                    id: meterRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: dashboardTop._spacing * dashboardTop._scale

                    // Session ring (left)
                    Column {
                        width: dashboardTop._ringSize
                        spacing: 2
                        DualQuotaRing {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: dashboardTop._ringSize; height: dashboardTop._ringSize
                            outerUsed: dashboardTop._sessionInUsed; outerLimit: dashboardTop._sessionInLimit; outerLabel: "in"
                            outerColor: outerPct > 0.9 ? Kirigami.Theme.negativeTextColor : outerPct > 0.7 ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.highlightColor
                            innerUsed: dashboardTop._sessionOutUsed; innerLimit: dashboardTop._sessionOutLimit; innerLabel: "out"
                            innerColor: innerPct > 0.9 ? Kirigami.Theme.negativeTextColor : innerPct > 0.7 ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.positiveTextColor
                        }
                        PlasmaComponents.Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: {
                                if (appRoot.sessionNumber > 0) return i18n("Session %1/%2", appRoot.sessionNumber, appRoot.sessionTotal)
                                if (dashboardTop._usingSessionFallback) return i18n("Session (est.)")
                                return i18n("Session")
                            }
                            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                            opacity: 0.35
                        }
                    }

                    // Throughput meter (center)
                    Column {
                        width: dashboardTop._tachoW
                        spacing: 2
                        Tachometer {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: dashboardTop._tachoW
                            height: dashboardTop._tachoW * 0.72
                            value: {
                                var v = appRoot.instantAllRate
                                if (v <= 0) v = appRoot.rateAll5m > 0 ? appRoot.rateAll5m : appRoot.rateAll30m
                                if (v > 0) return v
                                return dashboardTop._lastFineAllPerHour
                            }
                            avgValue: appRoot.rateAll30m > 0 ? appRoot.rateAll30m : dashboardTop._lastFineAllPerHour
                            maxValue: 300000000
                            label: i18n("tok/h")
                            innerValue: {
                                var v = appRoot.instantOutputRate
                                if (v <= 0) v = appRoot.rateOutput5m > 0 ? appRoot.rateOutput5m : appRoot.rateOutput30m
                                if (v > 0) return v
                                return dashboardTop._lastFineOutPerHour
                            }
                            innerMaxValue: 500000
                            activityLevel: appRoot.instantRate
                        }
                        PlasmaComponents.Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: i18n("Throughput")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                            opacity: 0.35
                        }
                    }

                    // Daily ring (right)
                    Column {
                        width: dashboardTop._ringSize
                        spacing: 2
                        DualQuotaRing {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: dashboardTop._ringSize; height: dashboardTop._ringSize
                            outerUsed: dashboardTop._dailyInUsed; outerLimit: dashboardTop._dailyInLimit; outerLabel: "in"
                            outerColor: outerPct > 0.9 ? Kirigami.Theme.negativeTextColor : outerPct > 0.7 ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.highlightColor
                            innerUsed: dashboardTop._dailyOutUsed; innerLimit: dashboardTop._dailyOutLimit; innerLabel: "out"
                            innerColor: innerPct > 0.9 ? Kirigami.Theme.negativeTextColor : innerPct > 0.7 ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.positiveTextColor
                        }
                        PlasmaComponents.Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: dashboardTop._usingDailyFallback ? i18n("Daily (avg)") : i18n("Daily")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                            opacity: 0.35
                        }
                    }
                }
            }

            // Session countdown
            PlasmaComponents.Label {
                visible: appRoot.sessionEndTs > 0
                text: {
                    var _t = appRoot.tick;
                    var endTs = appRoot.sessionEndTs;
                    if (endTs <= 0) return "";
                    var diffMs = endTs - Date.now();
                    if (diffMs <= 0) return i18n("Session ended");
                    var hours = Math.floor(diffMs / 3600000);
                    var mins = Math.floor((diffMs % 3600000) / 60000);
                    return i18n("Session ends in %1h %2m", hours, mins);
                }
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.4
                Layout.alignment: Qt.AlignHCenter
            }
        }

        // Prompt Stats
        ColumnLayout {
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("Prompt Stats") }
            GridLayout {
                Layout.fillWidth: true
                columns: 3; columnSpacing: Kirigami.Units.smallSpacing; rowSpacing: Kirigami.Units.smallSpacing
                StatCard { label: i18n("Today"); value: appRoot.promptsToday.toString(); accent: Kirigami.Theme.highlightColor; Layout.fillWidth: true }
                StatCard { label: i18n("Week"); value: appRoot.promptsWeek.toString(); accent: Kirigami.Theme.positiveTextColor; Layout.fillWidth: true }
                StatCard { label: i18n("Month"); value: appRoot.promptsMonth.toString(); accent: Kirigami.Theme.neutralTextColor; Layout.fillWidth: true }
            }
        }

        // Session Stats
        ColumnLayout {
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("Session Stats") }
            GridLayout {
                Layout.fillWidth: true
                columns: 3; columnSpacing: Kirigami.Units.smallSpacing; rowSpacing: Kirigami.Units.smallSpacing
                StatCard {
                    label: i18n("Active")
                    value: appRoot.activeSessions.toString()
                    accent: appRoot.activeSessions > 0 ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor
                    Layout.fillWidth: true
                }
                StatCard {
                    label: i18n("Window")
                    value: appRoot.sessionNumber > 0 ? (appRoot.sessionNumber + "/" + appRoot.sessionTotal) : "-"
                    accent: Kirigami.Theme.highlightColor
                    Layout.fillWidth: true
                }
                StatCard {
                    label: i18n("Input Used")
                    value: Api.formatTokens(appRoot.sessionInputUsed)
                    accent: Kirigami.Theme.neutralTextColor
                    Layout.fillWidth: true
                }
            }
        }

        // Token Usage Stats
        ColumnLayout {
            visible: appRoot.tokInToday > 0 || appRoot.tokOutToday > 0
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("Token Usage (Today)") }
            GridLayout {
                Layout.fillWidth: true
                columns: 2; columnSpacing: Kirigami.Units.smallSpacing; rowSpacing: Kirigami.Units.smallSpacing
                StatCard {
                    label: i18n("Input Tokens")
                    value: Api.formatTokens(appRoot.tokInToday)
                    accent: Kirigami.Theme.highlightColor
                    Layout.fillWidth: true
                }
                StatCard {
                    label: i18n("Output Tokens")
                    value: Api.formatTokens(appRoot.tokOutToday)
                    accent: Kirigami.Theme.positiveTextColor
                    Layout.fillWidth: true
                }
                StatCard {
                    label: i18n("Cache Read")
                    value: Api.formatTokens(appRoot.tokCacheReadToday)
                    accent: Kirigami.Theme.neutralTextColor
                    Layout.fillWidth: true
                }
                StatCard {
                    label: i18n("Cache Create")
                    value: Api.formatTokens(appRoot.tokCacheCreateToday)
                    accent: Kirigami.Theme.textColor
                    Layout.fillWidth: true
                }
            }
        }

        // Weekly Token Stats
        ColumnLayout {
            visible: appRoot.tokInWeek > 0 || appRoot.tokOutWeek > 0
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("Token Usage (Week)") }
            GridLayout {
                Layout.fillWidth: true
                columns: 2; columnSpacing: Kirigami.Units.smallSpacing; rowSpacing: Kirigami.Units.smallSpacing
                StatCard {
                    label: i18n("Input Tokens")
                    value: Api.formatTokens(appRoot.tokInWeek)
                    accent: Kirigami.Theme.highlightColor
                    Layout.fillWidth: true
                }
                StatCard {
                    label: i18n("Output Tokens")
                    value: Api.formatTokens(appRoot.tokOutWeek)
                    accent: Kirigami.Theme.positiveTextColor
                    Layout.fillWidth: true
                }
            }
        }

        // Token History (12h)
        Item {
            visible: appRoot.fineTokens.length > 0; Layout.fillWidth: true
            Layout.preferredHeight: appRoot.onDesktop ? Kirigami.Units.gridUnit * 8 : Kirigami.Units.gridUnit * 6
            Layout.margins: Kirigami.Units.smallSpacing
            ColumnLayout {
                anchors.fill: parent; spacing: Kirigami.Units.smallSpacing
                SectionHeader { text: appRoot.claudeFineWindowMode === "last_active" ? i18n("12h (last active)") : i18n("12h") }
                HourlyChart { Layout.fillWidth: true; Layout.fillHeight: true; rawData: appRoot.fineTokens; bucketMinutes: 5 }
            }
        }

        // Active Sessions
        ColumnLayout {
            visible: appRoot.activeSessionsList.length > 0
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing

            SectionHeader { text: i18n("Active Sessions") }

            Repeater {
                model: appRoot.activeSessionsList
                ActiveSessionCard {
                    required property var modelData
                    Layout.fillWidth: true
                    session: modelData
                    activity: (modelData.pid && appRoot.pidActivity[String(modelData.pid)]) ? appRoot.instantRate : 0
                }
            }
        }

        // Daily History
        Item {
            visible: appRoot.dailyTokens.length > 0; Layout.fillWidth: true
            Layout.preferredHeight: appRoot.onDesktop ? Kirigami.Units.gridUnit * 8 : Kirigami.Units.gridUnit * 6
            Layout.margins: Kirigami.Units.smallSpacing
            ColumnLayout {
                anchors.fill: parent; spacing: Kirigami.Units.smallSpacing
                SectionHeader { text: i18n("Daily History") }
                DailyChart { Layout.fillWidth: true; Layout.fillHeight: true; chartData: appRoot.dailyTokens }
            }
        }

        // Models
        ColumnLayout {
            id: modelsSection
            property var _modelKeys: Object.keys(appRoot.modelsUsed)
            property double _maxTok: {
                var max = 0
                for (var i = 0; i < _modelKeys.length; i++) {
                    var t = (appRoot.modelsUsed[_modelKeys[i]].input || 0) + (appRoot.modelsUsed[_modelKeys[i]].output || 0)
                    if (t > max) max = t
                }
                return max || 1
            }
            visible: _modelKeys.length > 0
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("Models") }
            Repeater {
                model: modelsSection._modelKeys
                ModelRow {
                    required property string modelData
                    Layout.fillWidth: true
                    modelName: modelData
                    inputTokens: appRoot.modelsUsed[modelData].input || 0
                    outputTokens: appRoot.modelsUsed[modelData].output || 0
                    cost: appRoot.modelsUsed[modelData].cost || 0
                    maxTokens: modelsSection._maxTok
                }
            }
        }

        // Recent Sessions
        ColumnLayout {
            visible: appRoot.recentSessions.length > 0
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("Recent Sessions") }
            Repeater {
                model: appRoot.recentSessions
                SessionRow { required property var modelData; Layout.fillWidth: true; sessionData: modelData }
            }
        }

        // Est cost
        PlasmaComponents.Label {
            visible: appRoot.showCosts && appRoot.estCostTotal > 0
            text: i18n("Est. API cost: %1 week / %2 total", Api.formatCost(appRoot.estCostWeek), Api.formatCost(appRoot.estCostTotal))
            font.pointSize: Kirigami.Theme.smallFont.pointSize * 1.05; opacity: 0.3
            Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; Layout.margins: Kirigami.Units.smallSpacing
        }

        Item { Layout.fillHeight: true }
    }
}
