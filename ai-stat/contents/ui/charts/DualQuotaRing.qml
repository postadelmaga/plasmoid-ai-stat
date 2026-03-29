import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

import "../../code/formatters.js" as Api

Item {
    id: dualRing

    // Outer ring
    property double outerUsed: 0
    property double outerLimit: 1
    property string outerLabel: ""
    property color outerColor: Kirigami.Theme.highlightColor

    // Inner ring
    property double innerUsed: 0
    property double innerLimit: 1
    property string innerLabel: ""
    property color innerColor: Kirigami.Theme.positiveTextColor

    property real outerPct: outerLimit > 0 ? Math.min(1.0, outerUsed / outerLimit) : 0
    property real innerPct: innerLimit > 0 ? Math.min(1.0, innerUsed / innerLimit) : 0

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var cx = width / 2, cy = height / 2
            var maxR = Math.min(cx, cy) - 4
            var outerLw = Math.max(5, maxR * 0.09)
            var innerLw = Math.max(4, maxR * 0.07)
            var gap = Math.max(3, maxR * 0.06)
            var outerR = maxR - outerLw / 2
            var innerR = outerR - outerLw / 2 - gap - innerLw / 2
            var tc = Kirigami.Theme.textColor
            var oc = dualRing.outerColor
            var ic = dualRing.innerColor

            // ── Outer ──
            // Track
            ctx.beginPath(); ctx.arc(cx, cy, outerR, 0, 2 * Math.PI)
            ctx.lineWidth = outerLw; ctx.lineCap = "round"
            ctx.strokeStyle = Qt.rgba(tc.r, tc.g, tc.b, 0.07); ctx.stroke()

            if (dualRing.outerPct > 0) {
                var outerEnd = -Math.PI / 2 + 2 * Math.PI * dualRing.outerPct
                // Glow
                ctx.beginPath(); ctx.arc(cx, cy, outerR, -Math.PI / 2, outerEnd)
                ctx.lineWidth = outerLw + 6; ctx.lineCap = "round"
                ctx.strokeStyle = Qt.rgba(oc.r, oc.g, oc.b, 0.10); ctx.stroke()
                // Arc
                ctx.beginPath(); ctx.arc(cx, cy, outerR, -Math.PI / 2, outerEnd)
                ctx.lineWidth = outerLw; ctx.lineCap = "round"
                ctx.strokeStyle = Qt.rgba(oc.r, oc.g, oc.b, 0.85); ctx.stroke()
            }

            // ── Inner ──
            // Track
            ctx.beginPath(); ctx.arc(cx, cy, innerR, 0, 2 * Math.PI)
            ctx.lineWidth = innerLw; ctx.lineCap = "round"
            ctx.strokeStyle = Qt.rgba(tc.r, tc.g, tc.b, 0.05); ctx.stroke()

            if (dualRing.innerPct > 0) {
                var innerEnd = -Math.PI / 2 + 2 * Math.PI * dualRing.innerPct
                // Glow
                ctx.beginPath(); ctx.arc(cx, cy, innerR, -Math.PI / 2, innerEnd)
                ctx.lineWidth = innerLw + 4; ctx.lineCap = "round"
                ctx.strokeStyle = Qt.rgba(ic.r, ic.g, ic.b, 0.08); ctx.stroke()
                // Arc
                ctx.beginPath(); ctx.arc(cx, cy, innerR, -Math.PI / 2, innerEnd)
                ctx.lineWidth = innerLw; ctx.lineCap = "round"
                ctx.strokeStyle = Qt.rgba(ic.r, ic.g, ic.b, 0.80); ctx.stroke()
            }
        }

        Timer { id: _repaintDebounce; interval: 30; onTriggered: canvas.requestPaint() }
        Connections {
            target: dualRing
            function onOuterPctChanged() { _repaintDebounce.restart() }
            function onInnerPctChanged() { _repaintDebounce.restart() }
            function onOuterColorChanged() { _repaintDebounce.restart() }
            function onInnerColorChanged() { _repaintDebounce.restart() }
        }

        Component.onCompleted: requestPaint()
    }

    // Center: two rows, each with colored value + label
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 2

        // Outer (primary)
        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            text: Api.formatTokens(dualRing.outerUsed)
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
            font.weight: Font.Bold
            color: dualRing.outerColor
        }

        // Inner (secondary)
        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            text: Api.formatTokens(dualRing.innerUsed)
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            font.weight: Font.DemiBold
            color: dualRing.innerColor
        }

        // Labels
        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            text: dualRing.outerLabel + " / " + dualRing.innerLabel
            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.82
            opacity: 0.25
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
