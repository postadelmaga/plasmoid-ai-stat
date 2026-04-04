import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

import "../../code/formatters.js" as Api

Item {
    id: tacho

    property real value: 0
    property real avgValue: 0
    property real maxValue: 200000000
    property real greenLimit: 0
    property string label: "tok/h"

    // Optional inner ring (concentric, thinner)
    property real innerValue: 0
    property real innerMaxValue: 0
    readonly property real _innerPct: innerMaxValue > 0 ? Math.min(1.0, innerValue / innerMaxValue) : 0
    readonly property color _innerColor: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.5)

    // Zone boundaries
    readonly property real greenFrac: greenLimit > 0 ? Math.min(greenLimit / maxValue, 0.5) : 0.5
    readonly property real yellowFrac: Math.min(greenFrac * 1.6, 0.80)

    property real pct: maxValue > 0 ? Math.min(1.0, value / maxValue) : 0
    property bool _rising: false  // tracked on value change, not per-frame
    property real avgPct: maxValue > 0 ? Math.min(1.0, avgValue / maxValue) : 0
    onPctChanged: { _rising = (pct > _prevPctSnap); _prevPctSnap = pct }
    property real _prevPctSnap: 0  // updated only on pct change, not per-frame

    // Engine vibration — jitter only while value is actively changing
    property real _jitter: 0
    property bool _active: false
    onValueChanged: { _active = true; _idleTimer.restart() }
    Timer { id: _idleTimer; interval: 4000; onTriggered: tacho._active = false }
    Timer {
        id: jitterTimer
        interval: 200
        running: tacho._active && tacho.pct > 0
        repeat: true
        onTriggered: {
            var amplitude = 0.3 + tacho.pct * 1.5
            tacho._jitter = (Math.random() - 0.5) * 2 * amplitude
        }
        onRunningChanged: if (!running) tacho._jitter = 0
    }

    // Needle color = zone color
    readonly property color needleColor: pct > yellowFrac ? "#ef5350"
                                       : pct > greenFrac ? "#ffb74d"
                                       : "#66bb6a"

    // Shared geometry
    readonly property real _cx: width / 2
    readonly property real _cy: height * 0.52
    readonly property real _r: Math.min(width / 2, height * 0.52) - 6
    readonly property int _lw: 6
    readonly property real _startRad: 3 * Math.PI / 4
    readonly property real _sweepRad: 3 * Math.PI / 2

    // Needle rotation (degrees, 0=north, clockwise)
    readonly property real _needleRotDeg: (_startRad + _sweepRad * pct) * (180 / Math.PI) + 90
    readonly property real _needleLen: _r - 14

    // ═══════════════════════════════════════════
    // STATIC BACKGROUND CANVAS
    // Repaints only on resize or zone changes (NOT on value updates)
    // ═══════════════════════════════════════════
    Canvas {
        id: bgCanvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()

            var cx = tacho._cx, cy = tacho._cy, r = tacho._r, lw = tacho._lw
            var startA = tacho._startRad, sweepA = tacho._sweepRad
            var tc = Kirigami.Theme.textColor

            var greenEnd = startA + sweepA * tacho.greenFrac
            var yellowEnd = startA + sweepA * tacho.yellowFrac
            var redEnd = startA + sweepA

            // Colored zone track
            ctx.lineCap = "butt"; ctx.lineWidth = lw
            ctx.beginPath(); ctx.arc(cx, cy, r, startA, greenEnd, false)
            ctx.strokeStyle = Qt.rgba(0.40, 0.73, 0.42, 0.15); ctx.stroke()
            ctx.beginPath(); ctx.arc(cx, cy, r, greenEnd, yellowEnd, false)
            ctx.strokeStyle = Qt.rgba(1.0, 0.72, 0.30, 0.13); ctx.stroke()
            ctx.beginPath(); ctx.arc(cx, cy, r, yellowEnd, redEnd, false)
            ctx.strokeStyle = Qt.rgba(0.94, 0.33, 0.31, 0.12); ctx.stroke()

            // Tick marks
            for (var i = 0; i <= 20; i++) {
                var tickAngle = startA + sweepA * (i / 20)
                var isMajor = (i % 5 === 0)
                var oR = r - lw / 2 - 2
                var iR = oR - (isMajor ? 7 : 3)
                ctx.beginPath()
                ctx.moveTo(cx + iR * Math.cos(tickAngle), cy + iR * Math.sin(tickAngle))
                ctx.lineTo(cx + oR * Math.cos(tickAngle), cy + oR * Math.sin(tickAngle))
                ctx.lineWidth = isMajor ? 1.5 : 0.5; ctx.lineCap = "round"
                ctx.strokeStyle = Qt.rgba(tc.r, tc.g, tc.b, isMajor ? 0.30 : 0.10)
                ctx.stroke()
            }

            // Scale labels
            var labelSize = Math.round(Kirigami.Theme.smallFont.pointSize * 0.6)
            ctx.font = "bold " + labelSize + "pt sans-serif"
            ctx.fillStyle = Qt.rgba(tc.r, tc.g, tc.b, 0.25); ctx.textAlign = "center"
            var l0r = r - lw / 2 - 16
            ctx.fillText("0", cx + l0r * Math.cos(startA), cy + l0r * Math.sin(startA) + labelSize / 2)
            var maxLabel = tacho.maxValue <= 1.0 ? "100%" : Api.formatTokens(tacho.maxValue)
            ctx.fillText(maxLabel, cx + l0r * Math.cos(startA + sweepA), cy + l0r * Math.sin(startA + sweepA) + labelSize / 2)

            // Inner concentric ring track (static part)
            if (tacho.innerMaxValue > 0) {
                var innerR = r - lw - 4
                var innerLw = 3
                ctx.beginPath(); ctx.arc(cx, cy, innerR, startA, startA + sweepA)
                ctx.lineWidth = innerLw; ctx.lineCap = "butt"
                ctx.strokeStyle = Qt.rgba(tc.r, tc.g, tc.b, 0.05); ctx.stroke()
            }
        }

        Timer {
            id: bgResizeDebounce; interval: 50; onTriggered: bgCanvas.requestPaint()
        }
        onWidthChanged: bgResizeDebounce.restart()
        onHeightChanged: bgResizeDebounce.restart()
        Connections {
            target: tacho
            function onGreenFracChanged() { bgCanvas.requestPaint() }
            function onMaxValueChanged() { bgCanvas.requestPaint() }
        }
        Component.onCompleted: requestPaint()
    }

    // ═══════════════════════════════════════════
    // DYNAMIC ARC CANVAS
    // Repaints on value/avg/inner changes (lightweight — arcs only)
    // ═══════════════════════════════════════════
    Canvas {
        id: arcCanvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()

            var cx = tacho._cx, cy = tacho._cy, r = tacho._r, lw = tacho._lw
            var startA = tacho._startRad, sweepA = tacho._sweepRad
            var tc = Kirigami.Theme.textColor
            var nc = tacho.needleColor

            // Active arc + glow
            if (tacho.pct > 0) {
                var arcEnd = startA + sweepA * tacho.pct

                ctx.beginPath(); ctx.arc(cx, cy, r, startA, arcEnd, false)
                ctx.lineWidth = lw + 10; ctx.lineCap = "round"
                ctx.strokeStyle = Qt.rgba(nc.r, nc.g, nc.b, 0.08)
                ctx.stroke()

                ctx.beginPath(); ctx.arc(cx, cy, r, startA, arcEnd, false)
                ctx.lineWidth = lw; ctx.lineCap = "round"
                ctx.strokeStyle = Qt.rgba(nc.r, nc.g, nc.b, 0.85)
                ctx.stroke()

                // Tip dot
                var tipX = cx + r * Math.cos(arcEnd)
                var tipY = cy + r * Math.sin(arcEnd)
                ctx.beginPath(); ctx.arc(tipX, tipY, lw * 0.65, 0, 2 * Math.PI)
                ctx.fillStyle = Qt.rgba(nc.r, nc.g, nc.b, 0.6)
                ctx.fill()
            }

            // Average marker
            if (tacho.avgPct > 0) {
                var avgAngle = startA + sweepA * tacho.avgPct
                var mOutR = r + lw / 2 + 3, mInR = r - lw / 2 - 3
                ctx.beginPath()
                ctx.moveTo(cx + mInR * Math.cos(avgAngle), cy + mInR * Math.sin(avgAngle))
                ctx.lineTo(cx + mOutR * Math.cos(avgAngle), cy + mOutR * Math.sin(avgAngle))
                ctx.lineWidth = 2; ctx.lineCap = "round"
                ctx.strokeStyle = Qt.rgba(tc.r, tc.g, tc.b, 0.55); ctx.stroke()
                ctx.beginPath()
                ctx.arc(cx + r * Math.cos(avgAngle), cy + r * Math.sin(avgAngle), 2.5, 0, 2 * Math.PI)
                ctx.fillStyle = Qt.rgba(1, 1, 1, 0.45); ctx.fill()
            }

            // Inner concentric ring active arc
            if (tacho._innerPct > 0) {
                var innerR = r - lw - 4
                var innerLw = 3
                ctx.beginPath(); ctx.arc(cx, cy, innerR, startA, startA + sweepA * tacho._innerPct)
                ctx.lineWidth = innerLw; ctx.lineCap = "round"
                ctx.strokeStyle = Qt.rgba(tc.r, tc.g, tc.b, 0.35); ctx.stroke()
            }
        }

        Timer {
            id: arcResizeDebounce; interval: 50; onTriggered: arcCanvas.requestPaint()
        }
        onWidthChanged: arcResizeDebounce.restart()
        onHeightChanged: arcResizeDebounce.restart()
        Connections {
            target: tacho
            function onValueChanged() { arcCanvas.requestPaint() }
            function onInnerValueChanged() { arcCanvas.requestPaint() }
            function onAvgPctChanged() { arcCanvas.requestPaint() }
        }
        Component.onCompleted: requestPaint()
    }

    // ═══════════════════════════════════════════
    // NEEDLE — rotated Rectangle (GPU transform, zero cost per frame)
    // Car tachometer feel: fast attack with overshoot, inertial decay, engine vibration
    // ═══════════════════════════════════════════
    // Outer pivot: smooth animated rotation from value (Behavior-driven)
    Item {
        id: needlePivot
        x: tacho._cx; y: tacho._cy
        width: 0; height: 0

        rotation: tacho._needleRotDeg

        Behavior on rotation {
            RotationAnimation {
                // Rise: fast snap with overshoot (like revving)
                // Fall: heavier, inertial return (like engine braking)
                duration: tacho._rising ? 350 : 900
                easing.type: tacho._rising ? Easing.OutBack : Easing.InOutQuad
                easing.overshoot: 1.2
                direction: RotationAnimation.Shortest
            }
        }

        // Inner item: raw jitter (no Behavior — instant, no animation queue)
        Item {
            id: needleJitter
            rotation: tacho._jitter

            // Needle body — tapered for realism
            Rectangle {
                x: -1.8; y: -tacho._needleLen
                width: 3.5; height: tacho._needleLen
                radius: 1.5
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(tacho.needleColor.r, tacho.needleColor.g, tacho.needleColor.b, 0.95) }
                    GradientStop { position: 0.7; color: Qt.rgba(tacho.needleColor.r, tacho.needleColor.g, tacho.needleColor.b, 0.6) }
                    GradientStop { position: 1.0; color: Qt.rgba(tacho.needleColor.r, tacho.needleColor.g, tacho.needleColor.b, 0.15) }
                }
            }

            // Needle shadow (offset for depth)
            Rectangle {
                x: 0.5; y: -tacho._needleLen + 2
                width: 3; height: tacho._needleLen
                radius: 1.5
                color: Qt.rgba(0, 0, 0, 0.18)
                z: -1
            }
        }
    }

    // Hub — layered circles for depth (all GPU composited)
    Rectangle {
        x: tacho._cx - 7; y: tacho._cy - 7; width: 14; height: 14; radius: 7
        color: Qt.rgba(0, 0, 0, 0.15)
    }
    Rectangle {
        x: tacho._cx - 6; y: tacho._cy - 6; width: 12; height: 12; radius: 6
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
    }
    Rectangle {
        x: tacho._cx - 4; y: tacho._cy - 4; width: 8; height: 8; radius: 4
        color: Qt.rgba(tacho.needleColor.r, tacho.needleColor.g, tacho.needleColor.b, 0.75)
    }
    Rectangle {
        x: tacho._cx - 2; y: tacho._cy - 2; width: 4; height: 4; radius: 2
        color: Qt.rgba(1, 1, 1, 0.5)
    }

    // Value readout — GPU-composited Label (no Canvas overhead)
    PlasmaComponents.Label {
        id: valueText
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: labelText.top
        anchors.bottomMargin: 1
        text: tacho.maxValue <= 1.0 ? Math.round(tacho.value * 100) + "%" : Api.formatTokens(Math.round(tacho.value))
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
        font.weight: Font.Bold
        color: tacho.needleColor
        horizontalAlignment: Text.AlignHCenter
    }

    PlasmaComponents.Label {
        id: labelText
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        text: tacho.label
        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
        opacity: 0.30
    }
}
