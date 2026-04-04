import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

import "../../code/formatters.js" as Api
import "../charts"
import "../components"

Flickable {
    id: piTab
    required property var appRoot
    contentWidth: width
    contentHeight: piCol.implicitHeight + Kirigami.Units.largeSpacing
    clip: true
    flickableDirection: Flickable.VerticalFlick
    QQC2.ScrollBar.vertical: QQC2.ScrollBar { id: scrollBar; policy: QQC2.ScrollBar.AsNeeded }

    ColumnLayout {
        id: piCol
        width: parent.width - Kirigami.Units.smallSpacing - (scrollBar.visible ? scrollBar.width : 0)
        spacing: Kirigami.Units.mediumSpacing

        // Section 1: Header
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                text: {
                    var parts = ["pi"]
                    if (appRoot.piProvider) parts.push(appRoot.piProvider)
                    if (appRoot.piModel) parts.push(appRoot.piModel)
                    if (appRoot.piThinkingLevel) parts.push("thinking:" + appRoot.piThinkingLevel)
                    return parts.join(" · ")
                }
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.5
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Item { Layout.fillWidth: true }

            RowLayout {
                visible: appRoot.piActiveSessions > 0
                spacing: Kirigami.Units.smallSpacing / 2
                Rectangle { width: 7; height: 7; radius: 3.5; color: Kirigami.Theme.positiveTextColor }
                PlasmaComponents.Label {
                    text: appRoot.piActiveSessions + " active"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    color: Kirigami.Theme.positiveTextColor; opacity: 0.7
                }
            }

            QQC2.BusyIndicator {
                running: appRoot.piLoading; visible: appRoot.piLoading
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
            QQC2.ToolButton { icon.name: "view-refresh"; onClicked: appRoot.refreshAll() }
        }

        // Section 2: Dashboard — Today Ring | Tachometer | Week Ring
        ColumnLayout {
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            Item {
                Layout.fillWidth: true
                property real _ringSize: Kirigami.Units.gridUnit * 6
                property real _tachoW: appRoot.onDesktop ? Kirigami.Units.gridUnit * 10 : Kirigami.Units.gridUnit * 8
                implicitHeight: piDashRow.implicitHeight

                Row {
                    id: piDashRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Kirigami.Units.smallSpacing

                    // Today ring (left)
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        DualQuotaRing {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: piDashRow.parent._ringSize; height: piDashRow.parent._ringSize
                            outerUsed: appRoot.piTokInToday; outerLimit: Math.max(appRoot.piTokInToday, appRoot.piTokOutToday, 1) * 1.25; outerLabel: "in"
                            outerColor: Kirigami.Theme.highlightColor
                            innerUsed: appRoot.piTokOutToday; innerLimit: Math.max(appRoot.piTokInToday, appRoot.piTokOutToday, 1) * 1.25; innerLabel: "out"
                            innerColor: Kirigami.Theme.positiveTextColor
                        }
                        PlasmaComponents.Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: i18n("Today")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                            opacity: 0.35
                        }
                    }

                    // Tachometer (center)
                    Tachometer {
                        anchors.verticalCenter: parent.verticalCenter
                        width: piDashRow.parent._tachoW; height: piDashRow.parent._tachoW * 0.72
                        value: appRoot.piInstantAllRate
                        avgValue: appRoot.piRateAll30m
                        maxValue: 300000000
                        label: i18n("tok/h")
                        innerValue: appRoot.piInstantOutputRate
                        innerMaxValue: 500000
                    }

                    // Week ring (right)
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        DualQuotaRing {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: piDashRow.parent._ringSize; height: piDashRow.parent._ringSize
                            outerUsed: appRoot.piTokInWeek; outerLimit: Math.max(appRoot.piTokInWeek, appRoot.piTokOutWeek, 1) * 1.25; outerLabel: "in"
                            outerColor: Kirigami.Theme.highlightColor
                            innerUsed: appRoot.piTokOutWeek; innerLimit: Math.max(appRoot.piTokInWeek, appRoot.piTokOutWeek, 1) * 1.25; innerLabel: "out"
                            innerColor: Kirigami.Theme.positiveTextColor
                        }
                        PlasmaComponents.Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: i18n("Week")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                            opacity: 0.35
                        }
                    }
                }
            }
        }

        // Section 2b: Stat cards — Costs + Prompts
        ColumnLayout {
            visible: appRoot.showCosts && appRoot.piCostMonth > 0
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("Costs") }
            GridLayout {
                Layout.fillWidth: true
                columns: 3; columnSpacing: Kirigami.Units.smallSpacing; rowSpacing: Kirigami.Units.smallSpacing
                StatCard { label: i18n("Today"); value: Api.formatCost(appRoot.piCostToday); accent: Kirigami.Theme.highlightColor; Layout.fillWidth: true }
                StatCard { label: i18n("Week"); value: Api.formatCost(appRoot.piCostWeek); accent: Kirigami.Theme.positiveTextColor; Layout.fillWidth: true }
                StatCard { label: i18n("Month"); value: Api.formatCost(appRoot.piCostMonth); accent: Kirigami.Theme.neutralTextColor; Layout.fillWidth: true }
            }
        }
        ColumnLayout {
            visible: appRoot.piPromptsMonth > 0
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("Prompts") }
            GridLayout {
                Layout.fillWidth: true
                columns: 3; columnSpacing: Kirigami.Units.smallSpacing; rowSpacing: Kirigami.Units.smallSpacing
                StatCard { label: i18n("Today"); value: String(appRoot.piPromptsToday); accent: Kirigami.Theme.highlightColor; Layout.fillWidth: true }
                StatCard { label: i18n("Week"); value: String(appRoot.piPromptsWeek); accent: Kirigami.Theme.positiveTextColor; Layout.fillWidth: true }
                StatCard { label: i18n("Month"); value: String(appRoot.piPromptsMonth); accent: Kirigami.Theme.neutralTextColor; Layout.fillWidth: true }
            }
        }

        // Section 4: 12h Token History Chart
        Item {
            visible: appRoot.piFineTokens.length > 0; Layout.fillWidth: true
            Layout.preferredHeight: appRoot.onDesktop ? Kirigami.Units.gridUnit * 8 : Kirigami.Units.gridUnit * 6
            Layout.margins: Kirigami.Units.smallSpacing
            ColumnLayout {
                anchors.fill: parent; spacing: Kirigami.Units.smallSpacing
                SectionHeader { text: i18n("12h") }
                HourlyChart { Layout.fillWidth: true; Layout.fillHeight: true; rawData: appRoot.piFineTokens; bucketMinutes: 5 }
            }
        }

        // Section 5: Daily History Chart
        Item {
            visible: appRoot.piDailyTokens.length > 0; Layout.fillWidth: true
            Layout.preferredHeight: appRoot.onDesktop ? Kirigami.Units.gridUnit * 8 : Kirigami.Units.gridUnit * 6
            Layout.margins: Kirigami.Units.smallSpacing
            ColumnLayout {
                anchors.fill: parent; spacing: Kirigami.Units.smallSpacing
                SectionHeader { text: i18n("Daily History") }
                DailyChart { Layout.fillWidth: true; Layout.fillHeight: true; chartData: appRoot.piDailyTokens }
            }
        }

        // Section 6: Models
        ColumnLayout {
            property var _modelKeys: Object.keys(appRoot.piModelsUsed).sort(function(a, b) {
                var ta = (appRoot.piModelsUsed[a].input || 0) + (appRoot.piModelsUsed[a].output || 0)
                var tb = (appRoot.piModelsUsed[b].input || 0) + (appRoot.piModelsUsed[b].output || 0)
                return tb - ta
            })
            property double _maxTok: {
                var max = 0
                for (var i = 0; i < _modelKeys.length; i++) {
                    var t = (appRoot.piModelsUsed[_modelKeys[i]].input || 0) + (appRoot.piModelsUsed[_modelKeys[i]].output || 0)
                    if (t > max) max = t
                }
                return max || 1
            }
            visible: _modelKeys.length > 0
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("Models") }
            Repeater {
                model: parent._modelKeys
                ColumnLayout {
                    required property string modelData
                    Layout.fillWidth: true
                    spacing: 1
                    ModelRow {
                        Layout.fillWidth: true
                        modelName: modelData
                        inputTokens: appRoot.piModelsUsed[modelData].input || 0
                        outputTokens: appRoot.piModelsUsed[modelData].output || 0
                        cost: appRoot.showCosts ? (appRoot.piModelsUsed[modelData].cost || 0) : 0
                        maxTokens: parent.parent._maxTok
                    }
                    PlasmaComponents.Label {
                        text: appRoot.piModelsUsed[modelData].provider || ""
                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
                        opacity: 0.35
                        Layout.leftMargin: Kirigami.Units.smallSpacing
                    }
                }
            }
        }

        // Section 7: Recent Sessions
        ColumnLayout {
            visible: appRoot.piRecentSessions.length > 0
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("Recent Sessions") }
            Repeater {
                model: appRoot.piRecentSessions
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
                                text: modelData.title || modelData.id || ""
                                font.pointSize: Kirigami.Theme.smallFont.pointSize; font.weight: Font.DemiBold
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                maximumLineCount: 1
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
                                visible: appRoot.showCosts && (modelData.cost || 0) > 0
                                text: Api.formatCost(modelData.cost || 0)
                                font.pointSize: Kirigami.Theme.smallFont.pointSize; color: Kirigami.Theme.neutralTextColor
                            }
                            PlasmaComponents.Label {
                                text: (modelData.model || "") + (modelData.provider ? " · " + modelData.provider : "")
                                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.95; opacity: 0.35
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            PlasmaComponents.Label {
                                visible: (modelData.prompts || 0) > 0
                                text: modelData.prompts + "p"
                                font.pointSize: Kirigami.Theme.smallFont.pointSize; opacity: 0.4
                            }
                        }
                    }
                }
            }
        }

        // Section 8: Footer
        PlasmaComponents.Label {
            text: { var d = new Date(); return i18n("Updated %1", d.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)) }
            font.pointSize: Kirigami.Theme.smallFont.pointSize * 1.05; opacity: 0.25
            Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; Layout.margins: Kirigami.Units.smallSpacing
        }
        Item { Layout.fillHeight: true }
    }
}
