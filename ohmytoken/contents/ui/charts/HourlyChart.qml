import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../../code/formatters.js" as Api

Canvas {
    id: chart
    property var rawData: []       // [{t: "HH:MM", input: N, output: N}, ...] (5-min buckets)
    property int bucketMinutes: 5  // granularity of rawData

    // Aggregate rawData into display points based on available width
    // Clean intervals that divide 720 min (12h): 5,10,15,20,30,60,120
    readonly property var _validIntervals: [5, 10, 15, 20, 30, 60, 120]
    readonly property int _minPointSpacing: 22  // minimum px between points

    property var chartData: {
        if (!rawData || rawData.length === 0) return []
        var pad = { left: 52, right: 14 }
        var usableW = width - pad.left - pad.right
        if (usableW <= 0) return rawData

        var maxPoints = Math.max(4, Math.floor(usableW / _minPointSpacing))
        // Pick the smallest clean interval that gives <= maxPoints
        var totalMinutes = rawData.length * bucketMinutes
        var chosenInterval = _validIntervals[_validIntervals.length - 1]
        for (var vi = 0; vi < _validIntervals.length; vi++) {
            var iv = _validIntervals[vi]
            if (iv < bucketMinutes) continue
            var nPts = Math.ceil(totalMinutes / iv)
            if (nPts <= maxPoints) { chosenInterval = iv; break }
        }

        var bucketsPerGroup = chosenInterval / bucketMinutes
        var result = []
        for (var i = 0; i < rawData.length; i += bucketsPerGroup) {
            var sumIn = 0, sumOut = 0
            var label = rawData[i].t
            var count = Math.min(bucketsPerGroup, rawData.length - i)
            for (var j = 0; j < count; j++) {
                sumIn += (rawData[i + j].input || 0)
                sumOut += (rawData[i + j].output || 0)
            }
            result.push({ t: label, input: sumIn, output: sumOut })
        }
        return result
    }

    // Debounce all repaints — chartData auto-recomputes via binding on width/rawData change
    Timer { id: paintDebounce; interval: 50; onTriggered: chart.requestPaint() }
    onChartDataChanged: paintDebounce.restart()
    onWidthChanged: paintDebounce.restart()
    onHeightChanged: paintDebounce.restart()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()

        if (!chartData || chartData.length === 0) return

        var n = chartData.length
        if (n < 2) return

        var pad = { top: 22, bottom: 22, left: 52, right: 14 }
        var w = width - pad.left - pad.right
        var h = height - pad.top - pad.bottom
        var baseline = pad.top + h

        var inpVals = new Array(n)
        var outVals = new Array(n)
        var maxIn = 0, maxOut = 0
        for (var i = 0; i < n; i++) {
            inpVals[i] = chartData[i].input || 0
            outVals[i] = chartData[i].output || 0
            if (inpVals[i] > maxIn) maxIn = inpVals[i]
            if (outVals[i] > maxOut) maxOut = outVals[i]
        }
        var hasAnyData = !(maxIn === 0 && maxOut === 0)

        var scaleIn = maxIn > 0 ? maxIn * 1.15 : 1
        var scaleOut
        if (maxOut === 0) {
            scaleOut = 1
        } else if (maxIn > 0 && maxOut < maxIn * 0.25) {
            scaleOut = maxOut / 0.30
        } else {
            scaleOut = scaleIn
        }

        var hlColor = Kirigami.Theme.highlightColor
        var posColor = Kirigami.Theme.positiveTextColor
        var textColor = Kirigami.Theme.textColor
        var bgColor = Kirigami.Theme.backgroundColor

        function px(idx) { return pad.left + (idx / (n - 1)) * w }
        function pyIn(v) { return baseline - (v / scaleIn) * h }
        function pyOut(v) { return baseline - (v / scaleOut) * h }

        // Catmull-Rom → Bezier
        function cmCP(p0, p1, p2, p3) {
            var t = 0.4
            return {
                c1x: p1.x + (p2.x - p0.x) * t / 3,
                c1y: p1.y + (p2.y - p0.y) * t / 3,
                c2x: p2.x - (p3.x - p1.x) * t / 3,
                c2y: p2.y - (p3.y - p1.y) * t / 3
            }
        }

        function buildPoints(vals, pyFn) {
            var pts = new Array(n)
            for (var i = 0; i < n; i++)
                pts[i] = { x: px(i), y: pyFn(vals[i]) }
            return pts
        }

        function traceCurve(ctx, pts) {
            ctx.moveTo(pts[0].x, pts[0].y)
            for (var i = 0; i < pts.length - 1; i++) {
                var p0 = pts[Math.max(0, i - 1)]
                var p1 = pts[i]
                var p2 = pts[i + 1]
                var p3 = pts[Math.min(pts.length - 1, i + 2)]
                var c = cmCP(p0, p1, p2, p3)
                ctx.bezierCurveTo(c.c1x, c.c1y, c.c2x, c.c2y, p2.x, p2.y)
            }
        }

        // ── Grid lines ──
        ctx.setLineDash([2, 5])
        ctx.lineWidth = 0.5
        var gridSteps = 4
        for (var g = 1; g < gridSteps; g++) {
            var gy = baseline - (g / gridSteps) * h
            var gv = (g / gridSteps) * scaleIn
            ctx.beginPath()
            ctx.moveTo(pad.left, gy)
            ctx.lineTo(pad.left + w, gy)
            ctx.strokeStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.07)
            ctx.stroke()
            if (maxIn > 0) {
                ctx.fillStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.6)
                ctx.font = "bold " + Math.round(Kirigami.Theme.smallFont.pointSize * 0.82) + "pt sans-serif"
                ctx.textAlign = "right"
                ctx.fillText(Api.formatTokens(Math.round(gv)), pad.left - 5, gy + 4)
            }
        }
        ctx.setLineDash([])

        // Baseline
        ctx.beginPath()
        ctx.moveTo(pad.left, baseline)
        ctx.lineTo(pad.left + w, baseline)
        ctx.strokeStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.12)
        ctx.lineWidth = 1
        ctx.stroke()

        var inPts = buildPoints(inpVals, pyIn)
        var outPts = buildPoints(outVals, pyOut)

        // ── Draw series ──
        function drawSeries(pts, vals, color, lineAlpha, fillAlpha, glowAlpha) {
            var hasData = false
            for (var k = 0; k < vals.length; k++)
                if (vals[k] > 0) { hasData = true; break }
            if (!hasData) return

            // Glow
            ctx.save()
            ctx.lineJoin = "round"; ctx.lineCap = "round"
            ctx.beginPath(); traceCurve(ctx, pts)
            ctx.strokeStyle = Qt.rgba(color.r, color.g, color.b, glowAlpha * 0.4)
            ctx.lineWidth = 12; ctx.stroke()
            ctx.beginPath(); traceCurve(ctx, pts)
            ctx.strokeStyle = Qt.rgba(color.r, color.g, color.b, glowAlpha * 0.7)
            ctx.lineWidth = 6; ctx.stroke()
            ctx.restore()

            // Area fill
            var peakY = baseline
            for (var k = 0; k < pts.length; k++)
                if (pts[k].y < peakY) peakY = pts[k].y
            var grad = ctx.createLinearGradient(0, peakY, 0, baseline)
            grad.addColorStop(0,   Qt.rgba(color.r, color.g, color.b, fillAlpha))
            grad.addColorStop(0.4, Qt.rgba(color.r, color.g, color.b, fillAlpha * 0.5))
            grad.addColorStop(0.8, Qt.rgba(color.r, color.g, color.b, fillAlpha * 0.1))
            grad.addColorStop(1,   Qt.rgba(color.r, color.g, color.b, 0))
            ctx.beginPath(); traceCurve(ctx, pts)
            ctx.lineTo(pts[pts.length - 1].x, baseline)
            ctx.lineTo(pts[0].x, baseline)
            ctx.closePath(); ctx.fillStyle = grad; ctx.fill()

            // Main line
            ctx.beginPath(); traceCurve(ctx, pts)
            ctx.strokeStyle = Qt.rgba(color.r, color.g, color.b, lineAlpha)
            ctx.lineWidth = 2.5; ctx.lineJoin = "round"; ctx.lineCap = "round"; ctx.stroke()

            // Dots at 30-min marks
            for (var d = 0; d < pts.length; d++) {
                if (vals[d] <= 0) continue
                var dt = chartData[d].t || ""
                var mm = dt.indexOf(":") >= 0 ? dt.split(":")[1] : ""
                var is30 = (mm === "00" || mm === "30")
                if (!is30 && d !== pts.length - 1) continue
                ctx.beginPath(); ctx.arc(pts[d].x, pts[d].y, 3.5, 0, Math.PI * 2)
                ctx.fillStyle = Qt.rgba(color.r, color.g, color.b, lineAlpha); ctx.fill()
                ctx.beginPath(); ctx.arc(pts[d].x, pts[d].y, 1.5, 0, Math.PI * 2)
                ctx.fillStyle = bgColor; ctx.fill()
            }
        }

        if (hasAnyData) {
            drawSeries(inPts, inpVals, hlColor, 0.95, 0.35, 0.18)
            drawSeries(outPts, outVals, posColor, 0.90, 0.25, 0.14)
        }

        // ── "Now" marker ──
        var lastX = px(n - 1)
        ctx.setLineDash([2, 3])
        ctx.beginPath(); ctx.moveTo(lastX, pad.top); ctx.lineTo(lastX, baseline)
        ctx.strokeStyle = Qt.rgba(hlColor.r, hlColor.g, hlColor.b, 0.15)
        ctx.lineWidth = 1; ctx.stroke()
        ctx.setLineDash([])
        ctx.beginPath()
        ctx.moveTo(lastX - 4, baseline + 2); ctx.lineTo(lastX + 4, baseline + 2); ctx.lineTo(lastX, baseline - 2)
        ctx.closePath(); ctx.fillStyle = Qt.rgba(hlColor.r, hlColor.g, hlColor.b, 0.45); ctx.fill()

        // ── X-axis labels + vertical gridlines ──
        var fontSize = Math.round(Kirigami.Theme.smallFont.pointSize * 0.95)
        ctx.font = fontSize + "pt sans-serif"
        ctx.textAlign = "center"

        // Pick a label step that avoids overlap (~45px min per label)
        var labelSpacingPx = 50
        var labelStep = Math.max(1, Math.round(n / Math.max(3, Math.floor(w / labelSpacingPx))))

        // Show evenly-spaced labels (skip last — that's "now")
        for (var j = 0; j < n - 1; j += labelStep) {
            var lx = px(j)
            // Vertical gridline
            ctx.beginPath()
            ctx.moveTo(lx, pad.top)
            ctx.lineTo(lx, baseline)
            ctx.strokeStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.06)
            ctx.lineWidth = 1
            ctx.setLineDash([2, 4])
            ctx.stroke()
            ctx.setLineDash([])
            // Label
            ctx.fillStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.45)
            ctx.fillText(chartData[j].t, lx, height - 4)
        }
        // Always show "now" label
        var nowX = px(n - 1)
        ctx.fillStyle = Qt.rgba(hlColor.r, hlColor.g, hlColor.b, 0.8)
        ctx.font = "bold " + fontSize + "pt sans-serif"
        ctx.fillText("now", nowX, height - 4)

        // ── Peak annotation ──
        var peakIdx = 0
        for (var pi = 1; pi < n; pi++)
            if (inpVals[pi] > inpVals[peakIdx]) peakIdx = pi

        if (hasAnyData && inpVals[peakIdx] > 0) {
            var pkx = inPts[peakIdx].x
            var pky = inPts[peakIdx].y
            var peakText = Api.formatTokens(inpVals[peakIdx])
            var pfs = Math.round(Kirigami.Theme.smallFont.pointSize * 0.85)
            ctx.font = "bold " + pfs + "pt sans-serif"

            var estW = peakText.length * (pfs * 0.9 + 1)
            var pillW = estW + 10
            var pillH = pfs + 8
            var pillX = pkx - pillW / 2
            var pillY = pky - pillH - 8

            if (pillX < pad.left) pillX = pad.left
            if (pillX + pillW > width - pad.right) pillX = width - pad.right - pillW
            if (pillY < 2) pillY = 2

            ctx.beginPath(); ctx.moveTo(pkx, pky - 5); ctx.lineTo(pkx, pillY + pillH)
            ctx.strokeStyle = Qt.rgba(hlColor.r, hlColor.g, hlColor.b, 0.25)
            ctx.lineWidth = 1; ctx.stroke()

            var r = 4
            ctx.beginPath()
            ctx.moveTo(pillX + r, pillY)
            ctx.lineTo(pillX + pillW - r, pillY)
            ctx.quadraticCurveTo(pillX + pillW, pillY, pillX + pillW, pillY + r)
            ctx.lineTo(pillX + pillW, pillY + pillH - r)
            ctx.quadraticCurveTo(pillX + pillW, pillY + pillH, pillX + pillW - r, pillY + pillH)
            ctx.lineTo(pillX + r, pillY + pillH)
            ctx.quadraticCurveTo(pillX, pillY + pillH, pillX, pillY + pillH - r)
            ctx.lineTo(pillX, pillY + r)
            ctx.quadraticCurveTo(pillX, pillY, pillX + r, pillY)
            ctx.closePath()
            ctx.fillStyle = Qt.rgba(hlColor.r, hlColor.g, hlColor.b, 0.18); ctx.fill()
            ctx.strokeStyle = Qt.rgba(hlColor.r, hlColor.g, hlColor.b, 0.3)
            ctx.lineWidth = 0.5; ctx.stroke()

            ctx.fillStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.85)
            ctx.textAlign = "center"
            ctx.fillText(peakText, pillX + pillW / 2, pillY + pillH - 3)
        }
    }

    // Legend
    Row {
        anchors.right: parent.right; anchors.top: parent.top
        anchors.topMargin: 2; anchors.rightMargin: 4
        spacing: Kirigami.Units.smallSpacing

        Rectangle { width: 12; height: 3; radius: 1.5; color: Kirigami.Theme.highlightColor; opacity: 0.9; anchors.verticalCenter: parent.verticalCenter }
        PlasmaComponents.Label { text: "In"; font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.92; opacity: 0.45 }
        Item { width: 4; height: 1 }
        Rectangle { width: 12; height: 3; radius: 1.5; color: Kirigami.Theme.positiveTextColor; opacity: 0.9; anchors.verticalCenter: parent.verticalCenter }
        PlasmaComponents.Label { text: "Out"; font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.92; opacity: 0.45 }
    }
}
