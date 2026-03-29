import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

import "../../code/formatters.js" as Api
import "../charts"
import "../components"

Flickable {
    id: gcliTab

    required property var appRoot

    contentWidth: width
    contentHeight: gcliCol.implicitHeight + Kirigami.Units.largeSpacing
    clip: true
    flickableDirection: Flickable.VerticalFlick
    QQC2.ScrollBar.vertical: QQC2.ScrollBar { id: scrollBar; policy: QQC2.ScrollBar.AsNeeded }

    ColumnLayout {
        id: gcliCol
        width: parent.width - Kirigami.Units.smallSpacing - (scrollBar.visible ? scrollBar.width : 0)
        spacing: Kirigami.Units.mediumSpacing

        // Header
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                text: {
                    var parts = [appRoot.gcliTier || "Gemini CLI"]
                    if (appRoot.gcliAccount) parts.push(appRoot.gcliAccount)
                    return parts.join(" \u00b7 ")
                }
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.5
                Layout.fillWidth: true
            }
            Item { Layout.fillWidth: true }

            RowLayout {
                visible: appRoot.gcliActiveSessions > 0
                spacing: Kirigami.Units.smallSpacing / 2
                Rectangle { width: 7; height: 7; radius: 3.5; color: Kirigami.Theme.positiveTextColor }
                PlasmaComponents.Label {
                    text: appRoot.gcliActiveSessions + " active"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    color: Kirigami.Theme.positiveTextColor; opacity: 0.7
                }
            }

            QQC2.BusyIndicator {
                running: appRoot.gcliLoading; visible: appRoot.gcliLoading
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
                StatCard { label: i18n("Today"); value: appRoot.gcliPromptsToday.toString(); accent: Kirigami.Theme.highlightColor; Layout.fillWidth: true }
                StatCard { label: i18n("Week"); value: appRoot.gcliPromptsWeek.toString(); accent: Kirigami.Theme.positiveTextColor; Layout.fillWidth: true }
                StatCard { label: i18n("Month"); value: appRoot.gcliPromptsMonth.toString(); accent: Kirigami.Theme.neutralTextColor; Layout.fillWidth: true }
            }
        }

        // ── Dashboard: Today Ring | Tachometer | Week Ring ──
        ColumnLayout {
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            Item {
                Layout.fillWidth: true
                property real _ringSize: Kirigami.Units.gridUnit * 6
                property real _tachoW: appRoot.onDesktop ? Kirigami.Units.gridUnit * 10 : Kirigami.Units.gridUnit * 8
                implicitHeight: gcliDashRow.implicitHeight

                Row {
                    id: gcliDashRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Kirigami.Units.smallSpacing

                    // Quota ring (left) — requests today vs daily limit
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        QuotaRing {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: gcliDashRow.parent._ringSize; height: gcliDashRow.parent._ringSize
                            used: appRoot.gcliReqToday; limit: appRoot.gcliReqLimit; label: "req/day"
                            ringColor: pct > 0.9 ? Kirigami.Theme.negativeTextColor : pct > 0.7 ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.highlightColor
                        }
                        PlasmaComponents.Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: i18n("Quota")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                            opacity: 0.35
                        }
                    }

                    // Tachometer (center)
                    Tachometer {
                        anchors.verticalCenter: parent.verticalCenter
                        width: gcliDashRow.parent._tachoW; height: gcliDashRow.parent._tachoW * 0.72
                        value: appRoot.gcliInstantAllRate
                        avgValue: appRoot.gcliRateAll30m
                        maxValue: 300000000
                        label: i18n("tok/h")
                        innerValue: appRoot.gcliInstantOutputRate
                        innerMaxValue: 500000
                    }

                    // Today tokens ring (right) — in/out
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        DualQuotaRing {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: gcliDashRow.parent._ringSize; height: gcliDashRow.parent._ringSize
                            outerUsed: appRoot.gcliTokInToday
                            outerLimit: Math.max(appRoot.gcliTokInWeek, appRoot.gcliTokInToday * 1.5, 1)
                            outerLabel: "in"
                            outerColor: Kirigami.Theme.highlightColor
                            innerUsed: appRoot.gcliTokOutToday
                            innerLimit: Math.max(appRoot.gcliTokOutWeek, appRoot.gcliTokOutToday * 1.5, 1)
                            innerLabel: "out"
                            innerColor: Kirigami.Theme.positiveTextColor
                        }
                        PlasmaComponents.Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: i18n("Today")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                            opacity: 0.35
                        }
                    }
                }
            }
        }

        // Token History (12h)
        Item {
            visible: appRoot.gcliFineTokens.length > 0; Layout.fillWidth: true
            Layout.preferredHeight: appRoot.onDesktop ? Kirigami.Units.gridUnit * 8 : Kirigami.Units.gridUnit * 6
            Layout.margins: Kirigami.Units.smallSpacing
            ColumnLayout {
                anchors.fill: parent; spacing: Kirigami.Units.smallSpacing
                SectionHeader { text: i18n("12h") }
                HourlyChart { Layout.fillWidth: true; Layout.fillHeight: true; rawData: appRoot.gcliFineTokens; bucketMinutes: 5 }
            }
        }

        // Daily History
        Item {
            visible: appRoot.gcliDailyTokens.length > 0; Layout.fillWidth: true
            Layout.preferredHeight: appRoot.onDesktop ? Kirigami.Units.gridUnit * 8 : Kirigami.Units.gridUnit * 6
            Layout.margins: Kirigami.Units.smallSpacing
            ColumnLayout {
                anchors.fill: parent; spacing: Kirigami.Units.smallSpacing
                SectionHeader { text: i18n("Daily History") }
                DailyChart { Layout.fillWidth: true; Layout.fillHeight: true; chartData: appRoot.gcliDailyTokens }
            }
        }

        // Models
        ColumnLayout {
            visible: Object.keys(appRoot.gcliModelsUsed).length > 0
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("Models") }
            Repeater {
                model: Object.keys(appRoot.gcliModelsUsed)
                ModelRow {
                    required property string modelData
                    Layout.fillWidth: true
                    modelName: modelData
                    inputTokens: appRoot.gcliModelsUsed[modelData].input || 0
                    outputTokens: appRoot.gcliModelsUsed[modelData].output || 0
                    cost: 0
                    maxTokens: {
                        var max = 0; var keys = Object.keys(appRoot.gcliModelsUsed)
                        for (var i = 0; i < keys.length; i++) {
                            var t = (appRoot.gcliModelsUsed[keys[i]].input || 0) + (appRoot.gcliModelsUsed[keys[i]].output || 0)
                            if (t > max) max = t
                        }
                        return max || 1
                    }
                }
            }
        }

        // Recent Sessions
        ColumnLayout {
            visible: appRoot.gcliRecentSessions.length > 0
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("Recent Sessions") }
            Repeater {
                model: appRoot.gcliRecentSessions
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
                                font.pointSize: Kirigami.Theme.smallFont.pointSize; font.weight: Font.DemiBold
                                Layout.fillWidth: true
                            }
                            PlasmaComponents.Label {
                                text: Api.formatDuration(modelData.duration_min || 0)
                                font.pointSize: Kirigami.Theme.smallFont.pointSize; opacity: 0.4
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            PlasmaComponents.Label {
                                text: Api.formatTokens(modelData.tokens || 0) + " tok"
                                font.pointSize: Kirigami.Theme.smallFont.pointSize; color: Kirigami.Theme.highlightColor
                            }
                            PlasmaComponents.Label {
                                text: modelData.model || ""
                                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.95; opacity: 0.35
                            }
                            Item { Layout.fillWidth: true }
                        }
                    }
                }
            }
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
