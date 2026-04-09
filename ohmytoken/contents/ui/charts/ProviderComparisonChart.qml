import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Canvas {
    id: chart

    property var xLabels: []  // ["HH:MM", ...] or ["YYYY-MM-DD", ...]
    property var series: []   // [{name: "Claude", color: color, values: [0..100, ...]}, ...]

    function _seriesColor(value) {
        if (value === undefined || value === null || value === "")
            return Kirigami.Theme.highlightColor
        if (typeof value === "string")
            return value

        var r = Number(value.r)
        var g = Number(value.g)
        var b = Number(value.b)
        var a = Number(value.a)
        if (!isFinite(r) || !isFinite(g) || !isFinite(b))
            return Kirigami.Theme.highlightColor
        if (!isFinite(a)) a = 1
        return Qt.rgba(r, g, b, a)
    }

    readonly property var activeSeries: {
        var labels = xLabels || []
        var count = labels.length
        if (count < 2) return []

        var out = []
        var src = series || []
        for (var i = 0; i < src.length; i++) {
            var row = src[i] || {}
            var values = row.values || []
            if (values.length < count) continue

            var normalized = []
            var hasData = false
            for (var j = 0; j < count; j++) {
                var v = Number(values[j])
                if (!isFinite(v)) v = 0
                v = Math.max(0, Math.min(100, v))
                normalized.push(v)
                if (v > 0) hasData = true
            }
            if (!hasData) continue

            out.push({
                name: row.name || "",
                color: _seriesColor(row.color),
                values: normalized
            })
        }
        return out
    }

    function _shortLabel(label) {
        if (!label) return ""
        if (label.length >= 10 && label.charAt(4) === "-" && label.charAt(7) === "-")
            return label.substring(8)
        return label
    }

    Timer { id: repaintDebounce; interval: 50; onTriggered: chart.requestPaint() }
    onXLabelsChanged: repaintDebounce.restart()
    onSeriesChanged: repaintDebounce.restart()
    onWidthChanged: repaintDebounce.restart()
    onHeightChanged: repaintDebounce.restart()
    onActiveSeriesChanged: repaintDebounce.restart()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()

        var labels = xLabels || []
        var n = labels.length
        if (n < 2 || activeSeries.length === 0) return

        var pad = { top: 22, bottom: 22, left: 38, right: 10 }
        var w = width - pad.left - pad.right
        var h = height - pad.top - pad.bottom
        if (w <= 0 || h <= 0) return

        var baseline = pad.top + h
        var textColor = Kirigami.Theme.textColor
        var hlColor = Kirigami.Theme.highlightColor
        var bgColor = Kirigami.Theme.backgroundColor

        function px(idx) { return pad.left + (idx / (n - 1)) * w }
        function py(valPct) { return baseline - (valPct / 100) * h }

        // Horizontal grid + y-axis labels
        for (var g = 0; g <= 4; g++) {
            var pct = g * 25
            var y = py(pct)

            ctx.beginPath()
            ctx.moveTo(pad.left, y)
            ctx.lineTo(pad.left + w, y)
            ctx.strokeStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, g === 0 ? 0.12 : 0.07)
            ctx.lineWidth = 1
            if (g !== 0) ctx.setLineDash([2, 4])
            ctx.stroke()
            ctx.setLineDash([])

            ctx.fillStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.55)
            ctx.font = Math.round(Kirigami.Theme.smallFont.pointSize * 0.82) + "pt sans-serif"
            ctx.textAlign = "right"
            ctx.fillText(pct + "%", pad.left - 5, y + 3)
        }

        // Provider lines
        for (var s = 0; s < activeSeries.length; s++) {
            var line = activeSeries[s]
            var c = line.color
            var glowAlpha = 0.16
            var lineAlpha = 0.94

            ctx.save()
            ctx.lineJoin = "round"
            ctx.lineCap = "round"

            // Glow pass (wide)
            ctx.globalAlpha = glowAlpha * 0.4
            ctx.beginPath()
            for (var i = 0; i < n; i++) {
                var gx = px(i)
                var gy = py(line.values[i])
                if (i === 0) ctx.moveTo(gx, gy)
                else ctx.lineTo(gx, gy)
            }
            ctx.strokeStyle = c
            ctx.lineWidth = 12
            ctx.stroke()

            // Glow pass (tight)
            ctx.globalAlpha = glowAlpha * 0.7
            ctx.beginPath()
            for (var i2 = 0; i2 < n; i2++) {
                var gx2 = px(i2)
                var gy2 = py(line.values[i2])
                if (i2 === 0) ctx.moveTo(gx2, gy2)
                else ctx.lineTo(gx2, gy2)
            }
            ctx.strokeStyle = c
            ctx.lineWidth = 6
            ctx.stroke()

            // Main line
            ctx.globalAlpha = lineAlpha
            ctx.beginPath()
            for (var i3 = 0; i3 < n; i3++) {
                var x = px(i3)
                var yv = py(line.values[i3])
                if (i3 === 0) ctx.moveTo(x, yv)
                else ctx.lineTo(x, yv)
            }
            ctx.strokeStyle = c
            ctx.lineWidth = 2.5
            ctx.stroke()
            ctx.restore()

            var lastX = px(n - 1)
            var lastY = py(line.values[n - 1])
            ctx.save()
            ctx.globalAlpha = lineAlpha
            ctx.beginPath()
            ctx.arc(lastX, lastY, 3.5, 0, Math.PI * 2)
            ctx.fillStyle = c
            ctx.fill()
            ctx.beginPath()
            ctx.arc(lastX, lastY, 1.5, 0, Math.PI * 2)
            ctx.fillStyle = bgColor
            ctx.fill()
            ctx.restore()
        }

        // X-axis labels
        var labelSpacingPx = 58
        var labelStep = Math.max(1, Math.round(n / Math.max(3, Math.floor(w / labelSpacingPx))))
        ctx.font = Math.round(Kirigami.Theme.smallFont.pointSize * 0.9) + "pt sans-serif"
        ctx.textAlign = "center"
        ctx.fillStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.45)
        for (var j = 0; j < n - 1; j += labelStep)
            ctx.fillText(_shortLabel(labels[j]), px(j), height - 4)

        // Last label (or "now" for clock data)
        var lastLabel = labels[n - 1] || ""
        var nowText = lastLabel.indexOf(":") >= 0 ? "now" : _shortLabel(lastLabel)
        ctx.font = "bold " + Math.round(Kirigami.Theme.smallFont.pointSize * 0.9) + "pt sans-serif"
        ctx.fillStyle = Qt.rgba(hlColor.r, hlColor.g, hlColor.b, 0.8)
        ctx.fillText(nowText, px(n - 1), height - 4)
    }

    Flow {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 4
        spacing: Kirigami.Units.smallSpacing

        Repeater {
            model: chart.activeSeries
            delegate: Row {
                required property var modelData
                spacing: 4
                Rectangle {
                    width: 10
                    height: 3
                    radius: 1.5
                    color: modelData.color
                    anchors.verticalCenter: parent.verticalCenter
                }
                PlasmaComponents.Label {
                    text: modelData.name
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                    opacity: 0.58
                }
            }
        }
    }
}
