import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

import "../../code/formatters.js" as Api
import "../charts"
import "../components"

Flickable {
    id: agTab

    required property var appRoot

    contentWidth: width
    contentHeight: agCol.implicitHeight + Kirigami.Units.largeSpacing
    clip: true
    flickableDirection: Flickable.VerticalFlick
    QQC2.ScrollBar.vertical: QQC2.ScrollBar { id: scrollBar; policy: QQC2.ScrollBar.AsNeeded }

    ColumnLayout {
        id: agCol
        width: parent.width - Kirigami.Units.smallSpacing - (scrollBar.visible ? scrollBar.width : 0)
        spacing: Kirigami.Units.mediumSpacing

        // Header
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                text: {
                    var parts = []
                    if (appRoot.agPlan) parts.push(appRoot.agPlan)
                    if (appRoot.agEmail) parts.push(appRoot.agEmail)
                    return parts.length > 0 ? parts.join(" \u00b7 ") : "Antigravity"
                }
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.5
                Layout.fillWidth: true
            }
            Item { Layout.fillWidth: true }

            QQC2.BusyIndicator {
                running: appRoot.agLoading; visible: appRoot.agLoading
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
            QQC2.ToolButton { icon.name: "view-refresh"; onClicked: appRoot.refreshAll() }
        }

        // Not running
        PlasmaComponents.Label {
            visible: !appRoot.agOk
            text: i18n("Antigravity IDE not running.")
            wrapMode: Text.Wrap; opacity: 0.6; Layout.fillWidth: true
            Layout.margins: Kirigami.Units.largeSpacing; horizontalAlignment: Text.AlignHCenter
        }

        // Credits Stats (like Prompt Stats in Claude)
        ColumnLayout {
            visible: appRoot.agOk
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("Credits") }
            GridLayout {
                Layout.fillWidth: true
                columns: 3; columnSpacing: Kirigami.Units.smallSpacing; rowSpacing: Kirigami.Units.smallSpacing
                StatCard { label: i18n("Prompt"); value: appRoot.agPromptCredits.toString(); sub: i18n("/ %1", appRoot.agPromptCreditsMax); accent: Kirigami.Theme.highlightColor; Layout.fillWidth: true }
                StatCard { label: i18n("Flow"); value: appRoot.agFlowCredits.toString(); sub: i18n("/ %1", appRoot.agFlowCreditsMax); accent: Kirigami.Theme.positiveTextColor; Layout.fillWidth: true }
                StatCard { label: i18n("Sessions"); value: appRoot.agRecentSessions.length.toString(); accent: Kirigami.Theme.neutralTextColor; Layout.fillWidth: true }
            }
        }

        // ── Dashboard: Credits Ring | Tachometer | Today Ring ──
        ColumnLayout {
            visible: appRoot.agOk
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            Item {
                Layout.fillWidth: true
                property real _ringSize: Kirigami.Units.gridUnit * 6
                property real _tachoW: appRoot.onDesktop ? Kirigami.Units.gridUnit * 10 : Kirigami.Units.gridUnit * 8
                implicitHeight: agDashRow.implicitHeight

                Row {
                    id: agDashRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Kirigami.Units.smallSpacing

                    // Credits ring (left)
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        DualQuotaRing {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: agDashRow.parent._ringSize; height: agDashRow.parent._ringSize
                            outerUsed: appRoot.agPromptCreditsMax - appRoot.agPromptCredits
                            outerLimit: Math.max(appRoot.agPromptCreditsMax, 1)
                            outerLabel: "prompt"
                            outerColor: outerPct > 0.9 ? Kirigami.Theme.negativeTextColor : outerPct > 0.7 ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.highlightColor
                            innerUsed: appRoot.agFlowCreditsMax - appRoot.agFlowCredits
                            innerLimit: Math.max(appRoot.agFlowCreditsMax, 1)
                            innerLabel: "flow"
                            innerColor: innerPct > 0.9 ? Kirigami.Theme.negativeTextColor : innerPct > 0.7 ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.positiveTextColor
                        }
                        PlasmaComponents.Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: i18n("Credits")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                            opacity: 0.35
                        }
                    }

                    // Tachometer (center)
                    // Use tok/h when rates are available, fall back to activity % otherwise
                    Tachometer {
                        property bool hasRates: appRoot.agRateAll5m > 0 || appRoot.agRateAll30m > 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: agDashRow.parent._tachoW; height: agDashRow.parent._tachoW * 0.72
                        value: hasRates ? appRoot.agInstantAllRate : appRoot.agInstantRate
                        avgValue: hasRates ? appRoot.agRateAll30m : 0
                        maxValue: hasRates ? 300000000 : 1.0
                        label: hasRates ? i18n("tok/h") : i18n("activity")
                        innerValue: hasRates ? appRoot.agInstantOutputRate : 0
                        innerMaxValue: hasRates ? 500000 : 0
                    }

                    // Today tokens ring (right)
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        DualQuotaRing {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: agDashRow.parent._ringSize; height: agDashRow.parent._ringSize
                            outerUsed: appRoot.agTokInToday
                            outerLimit: Math.max(appRoot.agTokInWeek, appRoot.agTokInToday * 1.5, 1)
                            outerLabel: "in"
                            outerColor: Kirigami.Theme.highlightColor
                            innerUsed: appRoot.agTokOutToday
                            innerLimit: Math.max(appRoot.agTokOutWeek, appRoot.agTokOutToday * 1.5, 1)
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

        // 12h Chart
        Item {
            visible: appRoot.agOk && appRoot.agFineTokens.length > 0; Layout.fillWidth: true
            Layout.preferredHeight: appRoot.onDesktop ? Kirigami.Units.gridUnit * 8 : Kirigami.Units.gridUnit * 6
            Layout.margins: Kirigami.Units.smallSpacing
            ColumnLayout {
                anchors.fill: parent; spacing: Kirigami.Units.smallSpacing
                SectionHeader { text: i18n("12h") }
                HourlyChart { Layout.fillWidth: true; Layout.fillHeight: true; rawData: appRoot.agFineTokens; bucketMinutes: 5 }
            }
        }

        // Recent Sessions
        ColumnLayout {
            visible: appRoot.agOk && appRoot.agRecentSessions.length > 0
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("Recent Sessions") }
            Repeater {
                model: appRoot.agRecentSessions
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
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            PlasmaComponents.Label {
                                text: Api.formatTokens(modelData.tokens || 0) + " tok"
                                font.pointSize: Kirigami.Theme.smallFont.pointSize; color: Kirigami.Theme.highlightColor
                            }
                            PlasmaComponents.Label {
                                text: "in:" + Api.formatTokens(modelData.input || 0) + " out:" + Api.formatTokens(modelData.output || 0)
                                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.95; opacity: 0.4
                            }
                            Item { Layout.fillWidth: true }
                        }
                    }
                }
            }
        }

        // Daily History
        Item {
            visible: appRoot.agOk && appRoot.agDailyTokens.length > 0; Layout.fillWidth: true
            Layout.preferredHeight: appRoot.onDesktop ? Kirigami.Units.gridUnit * 8 : Kirigami.Units.gridUnit * 6
            Layout.margins: Kirigami.Units.smallSpacing
            ColumnLayout {
                anchors.fill: parent; spacing: Kirigami.Units.smallSpacing
                SectionHeader { text: i18n("Daily History") }
                DailyChart { Layout.fillWidth: true; Layout.fillHeight: true; chartData: appRoot.agDailyTokens }
            }
        }

        // Model Quotas
        ColumnLayout {
            visible: appRoot.agOk && appRoot.agModels.length > 0
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("Model Quotas") }
            Repeater {
                model: appRoot.agModels
                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: mqRow.implicitHeight + Kirigami.Units.smallSpacing * 2
                    radius: Kirigami.Units.cornerRadius
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.03)

                    RowLayout {
                        id: mqRow
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Kirigami.Units.smallSpacing }
                        spacing: Kirigami.Units.smallSpacing
                        PlasmaComponents.Label {
                            text: modelData.label || ""
                            font.pointSize: Kirigami.Theme.smallFont.pointSize; font.weight: Font.DemiBold
                            Layout.fillWidth: true
                        }
                        PlasmaComponents.Label {
                            text: Math.round((modelData.remaining || 0) * 100) + "%"
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            color: modelData.remaining > 0.3 ? Kirigami.Theme.positiveTextColor
                                 : modelData.remaining > 0.1 ? Kirigami.Theme.neutralTextColor
                                 : Kirigami.Theme.negativeTextColor
                        }
                    }
                }
            }
        }

        // Footer
        PlasmaComponents.Label {
            visible: appRoot.agOk
            text: { var d = new Date(); return i18n("Updated %1", d.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)) }
            font.pointSize: Kirigami.Theme.smallFont.pointSize * 1.05; opacity: 0.25
            Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; Layout.margins: Kirigami.Units.smallSpacing
        }
        Item { Layout.fillHeight: true }
    }
}
