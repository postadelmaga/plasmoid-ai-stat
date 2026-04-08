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

    function openInFileManager(path) {
        if (!path || path.length === 0) return
        Qt.openUrlExternally("file://" + encodeURI(path))
    }

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

            PlasmaComponents.Label {
                text: appRoot.gcliLastFetchedMs > 0
                      ? i18n("Fetched %1", new Date(appRoot.gcliLastFetchedMs).toLocaleTimeString(Qt.locale(), Locale.ShortFormat))
                      : i18n("Fetched --")
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.92
                opacity: 0.45
            }

            QQC2.BusyIndicator {
                running: appRoot.gcliLoading; visible: appRoot.gcliLoading
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
                id: gcliDashboardTop
                Layout.fillWidth: true
                implicitHeight: gcliMetersRow.implicitHeight
                property real _spacing: Kirigami.Units.smallSpacing
                property real _targetRing: Kirigami.Units.gridUnit * (appRoot.onDesktop ? 6 : 5.6)
                property real _targetTacho: Kirigami.Units.gridUnit * (appRoot.onDesktop ? 10 : 8.8)
                property real _needed: (_targetRing * 2) + _targetTacho + (_spacing * 2)
                property real _scale: Math.min(1, Math.max(0.5, (width - Kirigami.Units.smallSpacing) / Math.max(_needed, 1)))
                property real _ringSize: _targetRing * _scale
                property real _tachoW: _targetTacho * _scale

                Row {
                    id: gcliMetersRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: gcliDashboardTop._spacing * gcliDashboardTop._scale

                    // Week tokens ring (left)
                    Column {
                        width: gcliDashboardTop._ringSize
                        spacing: 2
                        DualQuotaRing {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: gcliDashboardTop._ringSize
                            height: gcliDashboardTop._ringSize
                            outerUsed: appRoot.gcliTokInWeek
                            outerLimit: Math.max(appRoot.gcliTokInMonth, appRoot.gcliTokInWeek * 1.5, 1)
                            outerLabel: "in"
                            outerColor: Kirigami.Theme.highlightColor
                            innerUsed: appRoot.gcliTokOutWeek
                            innerLimit: Math.max(appRoot.gcliTokOutMonth, appRoot.gcliTokOutWeek * 1.5, 1)
                            innerLabel: "out"
                            innerColor: Kirigami.Theme.positiveTextColor
                        }
                        PlasmaComponents.Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: i18n("Week")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                            opacity: 0.35
                        }
                    }

                    // Throughput meter (center)
                    Column {
                        width: gcliDashboardTop._tachoW
                        spacing: 2
                        Tachometer {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: gcliDashboardTop._tachoW
                            height: gcliDashboardTop._tachoW * 0.72
                            value: appRoot.gcliInstantAllRate
                            avgValue: appRoot.gcliRateAll30m
                            maxValue: 300000000
                            label: i18n("tok/h")
                            innerValue: appRoot.gcliInstantOutputRate
                            innerMaxValue: 500000
                        }
                        PlasmaComponents.Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: i18n("Throughput")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                            opacity: 0.35
                        }
                    }

                    // Today tokens ring (right) — in/out
                    Column {
                        width: gcliDashboardTop._ringSize
                        spacing: 2
                        DualQuotaRing {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: gcliDashboardTop._ringSize
                            height: gcliDashboardTop._ringSize
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

        // Session Stats
        ColumnLayout {
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("Session Stats") }
            GridLayout {
                Layout.fillWidth: true
                columns: 3; columnSpacing: Kirigami.Units.smallSpacing; rowSpacing: Kirigami.Units.smallSpacing
                StatCard {
                    label: i18n("Active")
                    value: appRoot.gcliActiveSessions.toString()
                    accent: appRoot.gcliActiveSessions > 0 ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor
                    Layout.fillWidth: true
                }
                StatCard {
                    label: i18n("Total")
                    value: appRoot.gcliTotalSessions.toString()
                    accent: Kirigami.Theme.highlightColor
                    Layout.fillWidth: true
                }
                StatCard {
                    label: i18n("Requests Today")
                    value: appRoot.gcliReqToday.toString()
                    accent: Kirigami.Theme.neutralTextColor
                    Layout.fillWidth: true
                }
            }
        }

        // Token Usage (Today)
        ColumnLayout {
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("Token Usage (Today)") }
            GridLayout {
                Layout.fillWidth: true
                columns: 2; columnSpacing: Kirigami.Units.smallSpacing; rowSpacing: Kirigami.Units.smallSpacing
                StatCard {
                    label: i18n("Input Tokens")
                    value: Api.formatTokens(appRoot.gcliTokInToday)
                    accent: Kirigami.Theme.highlightColor
                    Layout.fillWidth: true
                }
                StatCard {
                    label: i18n("Output Tokens")
                    value: Api.formatTokens(appRoot.gcliTokOutToday)
                    accent: Kirigami.Theme.positiveTextColor
                    Layout.fillWidth: true
                }
            }
        }

        // Token Usage (Week)
        ColumnLayout {
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("Token Usage (Week)") }
            GridLayout {
                Layout.fillWidth: true
                columns: 2; columnSpacing: Kirigami.Units.smallSpacing; rowSpacing: Kirigami.Units.smallSpacing
                StatCard {
                    label: i18n("Input Tokens")
                    value: Api.formatTokens(appRoot.gcliTokInWeek)
                    accent: Kirigami.Theme.highlightColor
                    Layout.fillWidth: true
                }
                StatCard {
                    label: i18n("Output Tokens")
                    value: Api.formatTokens(appRoot.gcliTokOutWeek)
                    accent: Kirigami.Theme.positiveTextColor
                    Layout.fillWidth: true
                }
            }
        }

        // Token History (12h)
        Item {
            id: gcli12hSection
            property var _chartData: {
                var raw = appRoot.gcliFineTokens || []
                var normalized = []
                for (var i = 0; i < raw.length; i++) {
                    var e = raw[i] || {}
                    var label = e.t || ""
                    if (!label && e.ts) {
                        var d = new Date(e.ts)
                        label = Qt.formatTime(d, "hh:mm")
                    }
                    var input = Number(e.input || 0) + Number(e.cached || 0) + Number(e.thoughts || 0) + Number(e.tool || 0)
                    var output = Number(e.output || 0)
                    if (input <= 0 && output <= 0 && Number(e.total || 0) > 0) {
                        input = Number(e.total || 0)
                    }
                    normalized.push({
                        t: label,
                        input: Math.max(0, input),
                        output: Math.max(0, output)
                    })
                }
                return normalized
            }
            visible: _chartData.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: appRoot.onDesktop ? Kirigami.Units.gridUnit * 8 : Kirigami.Units.gridUnit * 6
            Layout.margins: Kirigami.Units.smallSpacing

            ColumnLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing
                SectionHeader { text: appRoot.gcliFineWindowMode === "last_active" ? i18n("12h (last active)") : i18n("12h") }
                HourlyChart {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    rawData: gcli12hSection._chartData
                    bucketMinutes: 5
                }
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
            id: gcliModelsSection
            property var _modelKeys: Object.keys(appRoot.gcliModelsUsed)
            property double _maxTok: {
                var max = 0
                for (var i = 0; i < _modelKeys.length; i++) {
                    var t = (appRoot.gcliModelsUsed[_modelKeys[i]].input || 0) + (appRoot.gcliModelsUsed[_modelKeys[i]].output || 0)
                    if (t > max) max = t
                }
                return max || 1
            }
            visible: _modelKeys.length > 0
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("Models") }
            Repeater {
                model: gcliModelsSection._modelKeys
                ModelRow {
                    required property string modelData
                    Layout.fillWidth: true
                    modelName: modelData
                    inputTokens: appRoot.gcliModelsUsed[modelData].input || 0
                    outputTokens: appRoot.gcliModelsUsed[modelData].output || 0
                    cost: 0
                    maxTokens: gcliModelsSection._maxTok
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
                    readonly property string rowPath: {
                        var p = modelData.project || modelData.cwd || modelData.path || ""
                        return (typeof p === "string" && p.length > 0 && p.charAt(0) === "/") ? p : ""
                    }
                    Layout.fillWidth: true
                    implicitHeight: sessCol.implicitHeight + Kirigami.Units.smallSpacing * 2
                    radius: Kirigami.Units.cornerRadius
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.03)
                    border.width: gcliRecentMouse.containsMouse ? 1 : 0
                    border.color: Kirigami.Theme.highlightColor

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

                    MouseArea {
                        id: gcliRecentMouse
                        anchors.fill: parent
                        enabled: parent.rowPath.length > 0
                        hoverEnabled: enabled
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: gcliTab.openInFileManager(parent.rowPath)
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
