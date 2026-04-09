import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

import "../../code/formatters.js" as Api
import "../charts"
import "../components"

Flickable {
    id: summaryTab

    required property var appRoot

    contentWidth: width
    contentHeight: summaryCol.implicitHeight + Kirigami.Units.largeSpacing
    clip: true
    flickableDirection: Flickable.VerticalFlick
    QQC2.ScrollBar.vertical: QQC2.ScrollBar { id: scrollBar; policy: QQC2.ScrollBar.AsNeeded }

    // Aggregate helpers
    readonly property double totalTokToday: {
        var t = 0
        if (appRoot.enableClaude) t += appRoot.tokInToday + appRoot.tokOutToday
        if (appRoot.enableGeminiCli) t += appRoot.gcliTokInToday + appRoot.gcliTokOutToday
        if (appRoot.enableAntigravity) t += appRoot.agTokInToday + appRoot.agTokOutToday
        if (appRoot.enableOpenCode) t += appRoot.ocTokInToday + appRoot.ocTokOutToday
        if (appRoot.enablePi) t += appRoot.piTokInToday + appRoot.piTokOutToday
        return t
    }
    readonly property double totalTokWeek: {
        var t = 0
        if (appRoot.enableClaude) t += appRoot.tokInWeek + appRoot.tokOutWeek
        if (appRoot.enableGeminiCli) t += appRoot.gcliTokInWeek + appRoot.gcliTokOutWeek
        if (appRoot.enableAntigravity) t += appRoot.agTokInWeek + appRoot.agTokOutWeek
        if (appRoot.enableOpenCode) t += appRoot.ocTokInWeek + appRoot.ocTokOutWeek
        if (appRoot.enablePi) t += appRoot.piTokInWeek + appRoot.piTokOutWeek
        return t
    }
    readonly property double totalTokMonth: {
        var t = 0
        if (appRoot.enableClaude) t += appRoot.tokInMonth + appRoot.tokOutMonth
        if (appRoot.enableGeminiCli) t += appRoot.gcliTokInMonth + appRoot.gcliTokOutMonth
        if (appRoot.enableAntigravity) t += appRoot.agTokInMonth + appRoot.agTokOutMonth
        if (appRoot.enableOpenCode) t += appRoot.ocTokInMonth + appRoot.ocTokOutMonth
        if (appRoot.enablePi) t += appRoot.piTokInMonth + appRoot.piTokOutMonth
        return t
    }
    readonly property int totalActiveSessions: {
        var n = 0
        if (appRoot.enableClaude) n += appRoot.activeSessions
        if (appRoot.enableGeminiCli) n += appRoot.gcliActiveSessions
        if (appRoot.enableOpenCode) n += appRoot.ocActiveSessions
        if (appRoot.enablePi) n += appRoot.piActiveSessions
        if (appRoot.enableCopilot) n += appRoot.copilotSessionsActive
        if (appRoot.enableKiro && appRoot.kiroRunning) n += 1
        return n
    }
    readonly property real combinedRate: Math.max(appRoot.instantAllRate, appRoot.gcliInstantAllRate, appRoot.ocInstantAllRate, appRoot.agInstantAllRate, appRoot.piInstantAllRate)
    readonly property real combinedOutputRate: Math.max(appRoot.instantOutputRate, appRoot.gcliInstantOutputRate, appRoot.ocInstantOutputRate, appRoot.agInstantOutputRate, appRoot.piInstantOutputRate)
    readonly property real combinedAvg: Math.max(appRoot.rateAll30m, appRoot.gcliRateAll30m, appRoot.ocRateAll30m, appRoot.agRateAll30m, appRoot.piRateAll30m)
    readonly property var mergedFineTokens: _aggregateSeries([
        appRoot.enableClaude ? appRoot.fineTokens : [],
        appRoot.enableGeminiCli ? appRoot.gcliFineTokens : [],
        appRoot.enableAntigravity ? appRoot.agFineTokens : [],
        appRoot.enableOpenCode ? appRoot.ocFineTokens : [],
        appRoot.enablePi ? appRoot.piFineTokens : []
    ], "t")
    readonly property var mergedDailyTokens: _aggregateSeries([
        appRoot.enableClaude ? appRoot.dailyTokens : [],
        appRoot.enableGeminiCli ? appRoot.gcliDailyTokens : [],
        appRoot.enableAntigravity ? appRoot.agDailyTokens : [],
        appRoot.enableOpenCode ? appRoot.ocDailyTokens : [],
        appRoot.enablePi ? appRoot.piDailyTokens : []
    ], "day")

    function _num(v) {
        var n = Number(v)
        return isFinite(n) ? n : 0
    }

    // Fixed provider palette for comparison charts (stable across periods/themes).
    readonly property var comparisonColorByProvider: ({
        claude: Qt.rgba(239 / 255, 108 / 255, 0 / 255, 1),
        gcli: Qt.rgba(30 / 255, 136 / 255, 229 / 255, 1),
        ag: Qt.rgba(142 / 255, 36 / 255, 170 / 255, 1),
        oc: Qt.rgba(0 / 255, 137 / 255, 123 / 255, 1),
        pi: Qt.rgba(216 / 255, 27 / 255, 96 / 255, 1),
        copilot: Qt.rgba(57 / 255, 73 / 255, 171 / 255, 1),
        kiro: Qt.rgba(109 / 255, 76 / 255, 65 / 255, 1)
    })

    function _comparisonColor(providerId) {
        var palette = comparisonColorByProvider || {}
        return palette[providerId] || Kirigami.Theme.highlightColor
    }

    function _aggregateSeries(allSeries, labelKey) {
        var seriesList = allSeries || []
        var sums = {}
        var order = []
        var seen = {}

        var base = []
        for (var i = 0; i < seriesList.length; i++) {
            var src = seriesList[i] || []
            if (src.length > base.length) base = src
        }

        for (var b = 0; b < base.length; b++) {
            var baseLabel = (base[b] || {})[labelKey] || ""
            if (!baseLabel || seen[baseLabel]) continue
            seen[baseLabel] = true
            order.push(baseLabel)
        }

        for (var s = 0; s < seriesList.length; s++) {
            var rows = seriesList[s] || []
            for (var r = 0; r < rows.length; r++) {
                var row = rows[r] || {}
                var label = row[labelKey] || ""
                if (!label) continue
                if (!seen[label]) {
                    seen[label] = true
                    order.push(label)
                }
                if (!sums[label]) sums[label] = { input: 0, output: 0 }
                sums[label].input += _num(row.input)
                sums[label].output += _num(row.output)
            }
        }

        if (labelKey === "day") order.sort()

        var out = []
        for (var o = 0; o < order.length; o++) {
            var key = order[o]
            var v = sums[key] || { input: 0, output: 0 }
            if (labelKey === "day")
                out.push({ day: key, input: v.input, output: v.output })
            else
                out.push({ t: key, input: v.input, output: v.output })
        }
        return out
    }

    function _providerRowsRaw() {
        var rows = []
        if (appRoot.enableClaude) {
            rows.push({
                id: "claude",
                providerName: "Claude",
                iconSource: Qt.resolvedUrl("../icons/claude.svg"),
                today: appRoot.tokInToday + appRoot.tokOutToday,
                baseline: appRoot.tokInWeek + appRoot.tokOutWeek,
                activeSessions: appRoot.activeSessions,
                accentColor: Kirigami.Theme.highlightColor,
                useRawNumber: false,
                primarySuffix: "",
                secondarySuffix: "w"
            })
        }
        if (appRoot.enableGeminiCli) {
            rows.push({
                id: "gcli",
                providerName: "Gemini CLI",
                iconSource: Qt.resolvedUrl("../icons/gemini.png"),
                today: appRoot.gcliTokInToday + appRoot.gcliTokOutToday,
                baseline: appRoot.gcliTokInWeek + appRoot.gcliTokOutWeek,
                activeSessions: appRoot.gcliActiveSessions,
                accentColor: Kirigami.Theme.positiveTextColor,
                useRawNumber: false,
                primarySuffix: "",
                secondarySuffix: "w"
            })
        }
        if (appRoot.enableAntigravity) {
            rows.push({
                id: "ag",
                providerName: "Antigravity",
                iconSource: Qt.resolvedUrl("../icons/antigravity.png"),
                today: appRoot.agTokInToday + appRoot.agTokOutToday,
                baseline: appRoot.agTokInWeek + appRoot.agTokOutWeek,
                activeSessions: 0,
                accentColor: Kirigami.Theme.neutralTextColor,
                useRawNumber: false,
                primarySuffix: "",
                secondarySuffix: "w"
            })
        }
        if (appRoot.enableOpenCode) {
            rows.push({
                id: "oc",
                providerName: "OpenCode",
                iconSource: Qt.resolvedUrl("../icons/opencode.svg"),
                today: appRoot.ocTokInToday + appRoot.ocTokOutToday,
                baseline: appRoot.ocTokInWeek + appRoot.ocTokOutWeek,
                activeSessions: appRoot.ocActiveSessions,
                accentColor: Kirigami.Theme.linkColor,
                useRawNumber: false,
                primarySuffix: "",
                secondarySuffix: "w"
            })
        }
        if (appRoot.enablePi) {
            rows.push({
                id: "pi",
                providerName: "Pi",
                iconSource: Qt.resolvedUrl("../icons/pi.svg"),
                today: appRoot.piTokInToday + appRoot.piTokOutToday,
                baseline: appRoot.piTokInWeek + appRoot.piTokOutWeek,
                activeSessions: appRoot.piActiveSessions,
                accentColor: Kirigami.Theme.visitedLinkColor,
                useRawNumber: false,
                primarySuffix: "",
                secondarySuffix: "w"
            })
        }
        if (appRoot.enableCopilot) {
            rows.push({
                id: "copilot",
                providerName: "Copilot CLI",
                iconSource: Qt.resolvedUrl("../icons/copilot.svg"),
                today: appRoot.copilotTurnsToday,
                baseline: appRoot.copilotTurnsWeek,
                activeSessions: appRoot.copilotSessionsActive,
                accentColor: Kirigami.Theme.highlightColor,
                useRawNumber: true,
                primarySuffix: " turns",
                secondarySuffix: "w"
            })
        }
        if (appRoot.enableKiro) {
            rows.push({
                id: "kiro",
                providerName: "Kiro",
                iconSource: Qt.resolvedUrl("../icons/kiro.png"),
                today: appRoot.kiroCreditsUsed,
                baseline: appRoot.kiroCreditsLimit,
                activeSessions: appRoot.kiroRunning ? 1 : 0,
                accentColor: Kirigami.Theme.linkColor,
                useRawNumber: true,
                primarySuffix: " used",
                secondarySuffix: " lim"
            })
        }
        for (var i = 0; i < rows.length; i++) {
            rows[i].today = _num(rows[i].today)
            rows[i].baseline = Math.max(1, _num(rows[i].baseline))
            rows[i].utilization = rows[i].today / rows[i].baseline
        }
        rows.sort(function(a, b) {
            if (b.utilization !== a.utilization) return b.utilization - a.utilization
            return b.today - a.today
        })
        return rows
    }

    readonly property var providerRows: _providerRowsRaw()
    readonly property double maxProviderToday: {
        var rows = providerRows || []
        var maxVal = 1
        for (var i = 0; i < rows.length; i++)
            maxVal = Math.max(maxVal, _num(rows[i].today))
        return maxVal
    }

    function _historyPoints(providerId, period) {
        var raw = []
        if (period === "fine") {
            if (providerId === "claude") raw = appRoot.fineTokens || []
            else if (providerId === "gcli") raw = appRoot.gcliFineTokens || []
            else if (providerId === "ag") raw = appRoot.agFineTokens || []
            else if (providerId === "oc") raw = appRoot.ocFineTokens || []
            else if (providerId === "pi") raw = appRoot.piFineTokens || []
            else if (providerId === "copilot") raw = appRoot.copilotFineTurns || []
        } else {
            if (providerId === "claude") raw = appRoot.dailyTokens || []
            else if (providerId === "gcli") raw = appRoot.gcliDailyTokens || []
            else if (providerId === "ag") raw = appRoot.agDailyTokens || []
            else if (providerId === "oc") raw = appRoot.ocDailyTokens || []
            else if (providerId === "pi") raw = appRoot.piDailyTokens || []
            else if (providerId === "copilot") raw = appRoot.copilotDailyTurns || []
        }

        var out = []
        for (var i = 0; i < raw.length; i++) {
            var row = raw[i] || {}
            var label = period === "fine" ? (row.t || "") : (row.day || "")
            if (!label) continue
            var value = providerId === "copilot" && period !== "fine"
                      ? _num(row.turns)
                      : _num(row.input) + _num(row.output)
            out.push({ label: label, value: value })
        }
        return out
    }

    function _labelsForPeriod(period) {
        var rows = providerRows || []
        var base = []
        for (var i = 0; i < rows.length; i++) {
            var pts = _historyPoints(rows[i].id, period)
            if (pts.length > base.length) base = pts
        }

        var labels = []
        var seen = {}
        for (var b = 0; b < base.length; b++) {
            var baseLabel = base[b].label
            if (!baseLabel || seen[baseLabel]) continue
            seen[baseLabel] = true
            labels.push(baseLabel)
        }
        for (var r = 0; r < rows.length; r++) {
            var pts2 = _historyPoints(rows[r].id, period)
            for (var p = 0; p < pts2.length; p++) {
                var label = pts2[p].label
                if (!label || seen[label]) continue
                seen[label] = true
                labels.push(label)
            }
        }
        if (period === "daily") labels.sort()
        return labels
    }

    function _comparisonSeries(period, labels) {
        if (!labels || labels.length < 2) return []
        var rows = providerRows || []
        var out = []
        for (var i = 0; i < rows.length; i++) {
            var row = rows[i]
            var pts = _historyPoints(row.id, period)
            if (!pts || pts.length === 0) continue

            var byLabel = {}
            for (var p = 0; p < pts.length; p++) {
                var point = pts[p]
                byLabel[point.label] = _num(byLabel[point.label]) + _num(point.value)
            }

            var values = []
            var maxVal = 0
            for (var j = 0; j < labels.length; j++) {
                var v = _num(byLabel[labels[j]])
                values.push(v)
                if (v > maxVal) maxVal = v
            }
            if (maxVal <= 0) continue

            var normalized = []
            for (var n = 0; n < values.length; n++)
                normalized.push((values[n] / maxVal) * 100)

            out.push({
                id: row.id,
                name: row.providerName,
                color: _comparisonColor(row.id),
                values: normalized
            })
        }
        return out
    }

    readonly property var comparisonFineLabels: _labelsForPeriod("fine")
    readonly property var comparisonFineSeries: _comparisonSeries("fine", comparisonFineLabels)
    readonly property var comparisonDailyLabels: _labelsForPeriod("daily")
    readonly property var comparisonDailySeries: _comparisonSeries("daily", comparisonDailyLabels)

    ColumnLayout {
        id: summaryCol
        width: parent.width - Kirigami.Units.smallSpacing - (scrollBar.visible ? scrollBar.width : 0)
        spacing: Kirigami.Units.mediumSpacing

        // Header
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                text: i18n("All Providers")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.5
                Layout.fillWidth: true
            }
            Item { Layout.fillWidth: true }

            RowLayout {
                visible: summaryTab.totalActiveSessions > 0
                spacing: Kirigami.Units.smallSpacing / 2
                Rectangle { width: 7; height: 7; radius: 3.5; color: Kirigami.Theme.positiveTextColor }
                PlasmaComponents.Label {
                    text: summaryTab.totalActiveSessions + " active"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    color: Kirigami.Theme.positiveTextColor; opacity: 0.7
                }
            }

            QQC2.ToolButton { icon.name: "view-refresh"; onClicked: appRoot.refreshAll() }
        }

        // Aggregate Token Stats
        ColumnLayout {
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("Total Tokens") }
            GridLayout {
                Layout.fillWidth: true
                columns: 3; columnSpacing: Kirigami.Units.smallSpacing; rowSpacing: Kirigami.Units.smallSpacing
                StatCard { label: i18n("Today"); value: Api.formatTokens(summaryTab.totalTokToday); accent: Kirigami.Theme.highlightColor; Layout.fillWidth: true }
                StatCard { label: i18n("Week"); value: Api.formatTokens(summaryTab.totalTokWeek); accent: Kirigami.Theme.positiveTextColor; Layout.fillWidth: true }
                StatCard { label: i18n("Month"); value: Api.formatTokens(summaryTab.totalTokMonth); accent: Kirigami.Theme.neutralTextColor; Layout.fillWidth: true }
            }
        }

        // Combined Tachometer
        Item {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            property real _tachoW: appRoot.onDesktop ? Kirigami.Units.gridUnit * 10 : Kirigami.Units.gridUnit * 8
            implicitHeight: _tachoW * 0.72

            Tachometer {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent._tachoW
                height: parent._tachoW * 0.72
                value: summaryTab.combinedRate
                avgValue: summaryTab.combinedAvg
                maxValue: 300000000
                label: i18n("tok/h")
                innerValue: summaryTab.combinedOutputRate
                innerMaxValue: 500000
            }
        }

        // Per-provider breakdown
        ColumnLayout {
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("Providers") }

            Repeater {
                model: summaryTab.providerRows
                delegate: ProviderRow {
                    required property var modelData
                    Layout.fillWidth: true
                    providerName: modelData.providerName
                    iconSource: modelData.iconSource
                    tokToday: modelData.today
                    tokWeek: modelData.baseline
                    activeSessions: modelData.activeSessions
                    accentColor: modelData.accentColor
                    totalToday: summaryTab.maxProviderToday
                    useRawNumber: modelData.useRawNumber
                    primarySuffix: modelData.primarySuffix
                    secondarySuffix: modelData.secondarySuffix
                }
            }
        }

        // 12h Totals
        Item {
            visible: summaryTab.mergedFineTokens.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: appRoot.onDesktop ? Kirigami.Units.gridUnit * 8 : Kirigami.Units.gridUnit * 6
            Layout.margins: Kirigami.Units.smallSpacing

            ColumnLayout {
                anchors.fill: parent; spacing: Kirigami.Units.smallSpacing
                SectionHeader { text: i18n("12h Totals") }
                HourlyChart { Layout.fillWidth: true; Layout.fillHeight: true; rawData: summaryTab.mergedFineTokens; bucketMinutes: 5 }
            }
        }

        // 12h Provider Comparison (normalized)
        Item {
            visible: summaryTab.comparisonFineSeries.length > 1 && summaryTab.comparisonFineLabels.length > 1
            Layout.fillWidth: true
            Layout.preferredHeight: appRoot.onDesktop ? Kirigami.Units.gridUnit * 8 : Kirigami.Units.gridUnit * 6
            Layout.margins: Kirigami.Units.smallSpacing

            ColumnLayout {
                anchors.fill: parent; spacing: Kirigami.Units.smallSpacing
                SectionHeader { text: i18n("12h Provider Comparison (%)") }
                ProviderComparisonChart {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    xLabels: summaryTab.comparisonFineLabels
                    series: summaryTab.comparisonFineSeries
                }
            }
        }

        // Daily Totals
        Item {
            visible: summaryTab.mergedDailyTokens.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: appRoot.onDesktop ? Kirigami.Units.gridUnit * 8 : Kirigami.Units.gridUnit * 6
            Layout.margins: Kirigami.Units.smallSpacing

            ColumnLayout {
                anchors.fill: parent; spacing: Kirigami.Units.smallSpacing
                SectionHeader { text: i18n("Daily Totals") }
                DailyChart { Layout.fillWidth: true; Layout.fillHeight: true; chartData: summaryTab.mergedDailyTokens }
            }
        }

        // Daily Provider Comparison (normalized)
        Item {
            visible: summaryTab.comparisonDailySeries.length > 1 && summaryTab.comparisonDailyLabels.length > 1
            Layout.fillWidth: true
            Layout.preferredHeight: appRoot.onDesktop ? Kirigami.Units.gridUnit * 8 : Kirigami.Units.gridUnit * 6
            Layout.margins: Kirigami.Units.smallSpacing

            ColumnLayout {
                anchors.fill: parent; spacing: Kirigami.Units.smallSpacing
                SectionHeader { text: i18n("Daily Provider Comparison (%)") }
                ProviderComparisonChart {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    xLabels: summaryTab.comparisonDailyLabels
                    series: summaryTab.comparisonDailySeries
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

    // ── ProviderRow: inline component for per-provider summary ──
    component ProviderRow: Rectangle {
        id: provRow
        property string providerName: ""
        property url iconSource: ""
        property double tokToday: 0
        property double tokWeek: 0
        property int activeSessions: 0
        property color accentColor: Kirigami.Theme.highlightColor
        property double totalToday: 1
        property bool useRawNumber: false
        property string primarySuffix: ""
        property string secondarySuffix: "w"

        function _fmt(v) {
            return useRawNumber ? Math.round(v).toString() : Api.formatTokens(v)
        }

        implicitHeight: provRowLayout.implicitHeight + Kirigami.Units.smallSpacing * 2
        radius: Kirigami.Units.cornerRadius
        color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.06)
        border.width: 1
        border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.12)

        // Usage proportion bar
        Rectangle {
            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
            radius: parent.radius
            width: parent.width * Math.min(1.0, totalToday > 0 ? tokToday / totalToday : 0)
            color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.06)
            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        }

        RowLayout {
            id: provRowLayout
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Kirigami.Units.smallSpacing }
            spacing: Kirigami.Units.smallSpacing

            Image {
                source: provRow.iconSource
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                sourceSize: Qt.size(width, height)
                opacity: 0.7
            }

            PlasmaComponents.Label {
                text: provRow.providerName
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }

            // Active dot
            Rectangle {
                visible: provRow.activeSessions > 0
                width: 6; height: 6; radius: 3
                color: Kirigami.Theme.positiveTextColor
            }

            PlasmaComponents.Label {
                text: provRow._fmt(provRow.tokToday) + provRow.primarySuffix
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.weight: Font.DemiBold
                color: provRow.accentColor
            }

            PlasmaComponents.Label {
                text: "/" + provRow._fmt(provRow.tokWeek) + provRow.secondarySuffix
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                opacity: 0.4
            }
        }
    }
}
