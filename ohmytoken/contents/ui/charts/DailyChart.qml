import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../../code/formatters.js" as Api

Canvas {
    id: chart
    property var chartData: []  // [{day: "2026-03-20", input: 123, output: 456}, ...]

    onChartDataChanged: requestPaint()
    Timer { id: dResizeDebounce; interval: 50; onTriggered: chart.requestPaint() }
    onWidthChanged: dResizeDebounce.restart()
    onHeightChanged: dResizeDebounce.restart()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()

        if (!chartData || chartData.length === 0) return

        var pad = { top: 14, bottom: 18, left: 4, right: 4 }
        var w = width - pad.left - pad.right
        var h = height - pad.top - pad.bottom
        var n = chartData.length
        var barW = Math.max(6, (w / n) - 6)
        var gap = (w - barW * n) / (n + 1)

        var maxVal = 0
        for (var i = 0; i < n; i++) {
            var total = (chartData[i].input || 0) + (chartData[i].output || 0)
            if (total > maxVal) maxVal = total
        }
        if (maxVal === 0) maxVal = 1

        var inColor = String(Kirigami.Theme.highlightColor)
        var outColor = String(Kirigami.Theme.positiveTextColor)
        var textColor = Kirigami.Theme.textColor

        for (var j = 0; j < n; j++) {
            var x = pad.left + gap + j * (barW + gap)
            var inH = ((chartData[j].input || 0) / maxVal) * h
            var outH = ((chartData[j].output || 0) / maxVal) * h
            var totalH = inH + outH

            // Input bar (bottom portion)
            if (inH > 0) {
                ctx.fillStyle = inColor
                ctx.globalAlpha = 0.8
                roundedRect(ctx, x, pad.top + h - totalH, barW, inH, 3)
                ctx.fill()
            }

            // Output bar (top portion, stacked)
            if (outH > 0) {
                ctx.fillStyle = outColor
                ctx.globalAlpha = 0.8
                roundedRect(ctx, x, pad.top + h - outH, barW, outH, 3)
                ctx.fill()
            }
            ctx.globalAlpha = 1.0

            // Day label
            ctx.fillStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.35)
            ctx.font = Math.round(Kirigami.Theme.smallFont.pointSize * 0.92) + "pt sans-serif"
            ctx.textAlign = "center"
            ctx.fillText(chartData[j].day.substring(8), x + barW / 2, height - 3)

            // Token count on top (or inside bar if no space above)
            var t = (chartData[j].input || 0) + (chartData[j].output || 0)
            if (t > 0) {
                var fontSize = Math.round(Kirigami.Theme.smallFont.pointSize * 0.82)
                ctx.font = fontSize + "pt sans-serif"
                var labelY = pad.top + h - totalH - 3
                if (labelY < pad.top + fontSize) {
                    // Not enough space above bar: draw inside
                    ctx.fillStyle = Qt.rgba(0, 0, 0, 0.7)
                    labelY = pad.top + h - totalH + fontSize + 2
                } else {
                    ctx.fillStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.45)
                }
                ctx.fillText(Api.formatTokens(t), x + barW / 2, labelY)
            }
        }
    }

    function roundedRect(ctx, x, y, w, h, r) {
        if (h <= 0) return
        r = Math.min(r, h / 2, w / 2)
        ctx.beginPath()
        ctx.moveTo(x + r, y)
        ctx.lineTo(x + w - r, y)
        ctx.quadraticCurveTo(x + w, y, x + w, y + r)
        ctx.lineTo(x + w, y + h - r)
        ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h)
        ctx.lineTo(x + r, y + h)
        ctx.quadraticCurveTo(x, y + h, x, y + h - r)
        ctx.lineTo(x, y + r)
        ctx.quadraticCurveTo(x, y, x + r, y)
        ctx.closePath()
    }

    // Legend
    Row {
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Kirigami.Units.smallSpacing

        Rectangle { width: 8; height: 8; radius: 2; color: Kirigami.Theme.highlightColor; anchors.verticalCenter: parent.verticalCenter }
        PlasmaComponents.Label { text: "In"; font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.95; opacity: 0.5 }
        Rectangle { width: 8; height: 8; radius: 2; color: Kirigami.Theme.positiveTextColor; anchors.verticalCenter: parent.verticalCenter }
        PlasmaComponents.Label { text: "Out"; font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.95; opacity: 0.5 }
    }
}
