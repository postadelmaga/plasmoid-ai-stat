import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

import "../../code/formatters.js" as Api

Item {
    id: quotaRing

    property double used: 0
    property double limit: 1
    property string label: ""
    property color ringColor: Kirigami.Theme.highlightColor
    property bool compact: false

    property alias ringWidth: quotaRing.width
    property alias ringHeight: quotaRing.height

    property real pct: limit > 0 ? Math.min(1.0, used / limit) : 0

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var cx = width / 2, cy = height / 2
            var r = Math.min(cx, cy) - 6
            var lw = 7

            // Track
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, 2 * Math.PI)
            ctx.lineWidth = lw
            ctx.lineCap = "round"
            ctx.strokeStyle = Qt.rgba(Kirigami.Theme.textColor.r,
                                      Kirigami.Theme.textColor.g,
                                      Kirigami.Theme.textColor.b, 0.08)
            ctx.stroke()

            // Arc
            if (quotaRing.pct > 0) {
                ctx.beginPath()
                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * quotaRing.pct)
                ctx.lineWidth = lw
                ctx.lineCap = "round"
                ctx.strokeStyle = quotaRing.ringColor
                ctx.stroke()
            }
        }

        Connections {
            target: quotaRing
            function onPctChanged() { canvas.requestPaint() }
        }

        Component.onCompleted: requestPaint()
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 0

        PlasmaComponents.Label {
            visible: !quotaRing.compact
            text: Api.formatTokens(quotaRing.used)
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
        }
        PlasmaComponents.Label {
            visible: !quotaRing.compact
            text: Api.formatTokens(quotaRing.limit)
            font.pointSize: Kirigami.Theme.smallFont.pointSize * 1.0
            opacity: 0.4
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
        }
        PlasmaComponents.Label {
            text: quotaRing.label
            font.pointSize: quotaRing.compact ? Kirigami.Theme.defaultFont.pointSize * 1.1 : Kirigami.Theme.smallFont.pointSize * 0.92
            font.weight: quotaRing.compact ? Font.Bold : Font.Normal
            color: quotaRing.compact ? quotaRing.ringColor : Kirigami.Theme.textColor
            opacity: quotaRing.compact ? 0.9 : 0.3
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
