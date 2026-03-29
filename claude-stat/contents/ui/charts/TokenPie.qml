import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

import "../../code/formatters.js" as Api

Canvas {
    id: pie

    property double inputTokens: 0
    property double outputTokens: 0
    property double cacheTokens: 0

    property double total: inputTokens + outputTokens + cacheTokens

    onInputTokensChanged: requestPaint()
    onOutputTokensChanged: requestPaint()
    onCacheTokensChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()

        var cx = width / 2, cy = height / 2
        var r = Math.min(cx, cy) - 4
        var innerR = r * 0.55

        if (total <= 0) {
            // Empty state: gray ring
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, 2 * Math.PI)
            ctx.arc(cx, cy, innerR, 2 * Math.PI, 0, true)
            ctx.closePath()
            ctx.fillStyle = Qt.rgba(Kirigami.Theme.textColor.r,
                                    Kirigami.Theme.textColor.g,
                                    Kirigami.Theme.textColor.b, 0.06)
            ctx.fill()
            return
        }

        var slices = [
            { value: inputTokens, color: String(Kirigami.Theme.highlightColor) },
            { value: outputTokens, color: String(Kirigami.Theme.positiveTextColor) },
            { value: cacheTokens, color: "#ce93d8" }
        ]

        var startAngle = -Math.PI / 2
        var gap = 0.03 // Small gap between slices

        for (var i = 0; i < slices.length; i++) {
            if (slices[i].value <= 0) continue

            var sweep = (slices[i].value / total) * 2 * Math.PI
            var endAngle = startAngle + sweep

            ctx.beginPath()
            ctx.arc(cx, cy, r, startAngle + gap, endAngle - gap)
            ctx.arc(cx, cy, innerR, endAngle - gap, startAngle + gap, true)
            ctx.closePath()
            ctx.fillStyle = slices[i].color
            ctx.globalAlpha = 0.85
            ctx.fill()
            ctx.globalAlpha = 1.0

            startAngle = endAngle
        }
    }

    // Center label
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 0

        PlasmaComponents.Label {
            text: Api.formatTokens(pie.total)
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.0
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
        }
        PlasmaComponents.Label {
            text: "today"
            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.92
            opacity: 0.4
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
        }
    }

    // Legend below
    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Kirigami.Units.smallSpacing

        Rectangle { width: 6; height: 6; radius: 1; color: Kirigami.Theme.highlightColor; anchors.verticalCenter: parent.verticalCenter }
        PlasmaComponents.Label { text: "In"; font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.88; opacity: 0.45 }
        Rectangle { width: 6; height: 6; radius: 1; color: Kirigami.Theme.positiveTextColor; anchors.verticalCenter: parent.verticalCenter }
        PlasmaComponents.Label { text: "Out"; font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.88; opacity: 0.45 }
        Rectangle { width: 6; height: 6; radius: 1; color: "#ce93d8"; anchors.verticalCenter: parent.verticalCenter; visible: pie.cacheTokens > 0 }
        PlasmaComponents.Label { text: "Cache"; font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.88; opacity: 0.45; visible: pie.cacheTokens > 0 }
    }
}
