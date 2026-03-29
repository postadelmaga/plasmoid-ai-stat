import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

import "../../code/anthropic.js" as Api
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

            QQC2.BusyIndicator {
                running: appRoot.loading; visible: appRoot.loading
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
            QQC2.ToolButton { icon.name: "view-refresh"; onClicked: appRoot.refreshAll() }
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

        // Throughput
        ColumnLayout {
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing

            SectionHeader { text: i18n("Throughput") }

            // Main gauge (outer): all tokens incl. cache (quota burn rate)
            // Inner ring (thin): output only (Claude's generated text)
            Tachometer {
                Layout.preferredWidth: appRoot.onDesktop ? Kirigami.Units.gridUnit * 10 : Kirigami.Units.gridUnit * 8
                Layout.preferredHeight: Layout.preferredWidth * 0.72
                Layout.alignment: Qt.AlignHCenter
                value: appRoot.instantAllRate
                avgValue: appRoot.rateAll30m
                maxValue: 300000000   // 300M tok/h — quota burn scale
                label: i18n("tok/h")
                // Inner ring: output only (actual generated text)
                innerValue: appRoot.instantOutputRate
                innerMaxValue: 500000  // 500K tok/h output scale
            }
        }

        // Token History (12h)
        Item {
            visible: appRoot.fineTokens.length > 0; Layout.fillWidth: true
            Layout.preferredHeight: appRoot.onDesktop ? Kirigami.Units.gridUnit * 8 : Kirigami.Units.gridUnit * 6
            Layout.margins: Kirigami.Units.smallSpacing
            ColumnLayout {
                anchors.fill: parent; spacing: Kirigami.Units.smallSpacing
                SectionHeader { text: i18n("12h") }
                HourlyChart { Layout.fillWidth: true; Layout.fillHeight: true; rawData: appRoot.fineTokens; bucketMinutes: 5 }
            }
        }

        // Session Quota
        ColumnLayout {
            visible: appRoot.hasLimits && appRoot.sessionInputLimit > 0
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            SectionHeader { text: i18n("Session %1/%2", appRoot.sessionNumber, appRoot.sessionTotal) }

            Row {
                Layout.alignment: Qt.AlignHCenter; spacing: Kirigami.Units.largeSpacing
                QuotaRing {
                    ringWidth: Kirigami.Units.gridUnit * 6; ringHeight: Kirigami.Units.gridUnit * 6
                    used: appRoot.sessionInputUsed; limit: appRoot.sessionInputLimit; label: "input"
                    ringColor: pct > 0.9 ? Kirigami.Theme.negativeTextColor : pct > 0.7 ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.highlightColor
                }
                QuotaRing {
                    ringWidth: Kirigami.Units.gridUnit * 6; ringHeight: Kirigami.Units.gridUnit * 6
                    used: appRoot.sessionOutputUsed; limit: appRoot.sessionOutputLimit; label: "output"
                    ringColor: pct > 0.9 ? Kirigami.Theme.negativeTextColor : pct > 0.7 ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.positiveTextColor
                }
            }

            PlasmaComponents.Label {
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

            PlasmaComponents.Label {
                text: i18n("Daily: %1 / %2 input \u00b7 %3 / %4 output",
                    Api.formatTokens(appRoot.tokInToday), Api.formatTokens(appRoot.limInTokPerDay),
                    Api.formatTokens(appRoot.tokOutToday), Api.formatTokens(appRoot.limOutTokPerDay))
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 1.05
                opacity: 0.3
                Layout.alignment: Qt.AlignHCenter
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
            visible: Object.keys(appRoot.modelsUsed).length > 0
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("Models") }
            Repeater {
                model: Object.keys(appRoot.modelsUsed)
                ModelRow {
                    required property string modelData
                    Layout.fillWidth: true
                    modelName: modelData
                    inputTokens: appRoot.modelsUsed[modelData].input || 0
                    outputTokens: appRoot.modelsUsed[modelData].output || 0
                    cost: appRoot.modelsUsed[modelData].cost || 0
                    maxTokens: {
                        var max = 0; var keys = Object.keys(appRoot.modelsUsed)
                        for (var i = 0; i < keys.length; i++) {
                            var t = (appRoot.modelsUsed[keys[i]].input || 0) + (appRoot.modelsUsed[keys[i]].output || 0)
                            if (t > max) max = t
                        }
                        return max || 1
                    }
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

        // Footer
        PlasmaComponents.Label {
            text: { var d = new Date(); return i18n("Updated %1", d.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)) }
            font.pointSize: Kirigami.Theme.smallFont.pointSize * 1.05; opacity: 0.25
            Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; Layout.margins: Kirigami.Units.smallSpacing
        }
        Item { Layout.fillHeight: true }
    }
}
