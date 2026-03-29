import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

import "../code/anthropic.js" as Api
import "tabs"
import "charts"
import "components"

PlasmoidItem {
    id: root

    // ── Configuration ──
    property int refreshInterval: plasmoid.configuration.refreshInterval || 300
    property double monthlyBudget: plasmoid.configuration.monthlyBudget || 100
    property bool showCosts: plasmoid.configuration.showCosts !== false
    property int dailyInputLimitM: plasmoid.configuration.dailyInputLimitM || 0
    property int dailyOutputLimitM: plasmoid.configuration.dailyOutputLimitM || 0
    property string geminiApiKey: plasmoid.configuration.geminiApiKey || ""
    property string compactStyle: plasmoid.configuration.compactStyle || "ring"

    property bool onDesktop: Plasmoid.formFactor === 0
    preferredRepresentation: onDesktop ? fullRepresentation : compactRepresentation

    // ── Claude state ──
    property bool loading: false
    property string subType: ""
    property string tierName: ""
    property int activeSessions: 0
    property int promptsToday: 0
    property int promptsWeek: 0
    property int promptsMonth: 0
    property bool hasLimits: false
    property int limInTokPerDay: 0
    property int limOutTokPerDay: 0
    property int tokInToday: 0
    property int tokOutToday: 0
    property int tokCacheReadToday: 0
    property int tokCacheCreateToday: 0
    property int tokInWeek: 0
    property int tokOutWeek: 0
    property int tokInMonth: 0
    property int tokOutMonth: 0
    property double estCostWeek: 0
    property double estCostTotal: 0
    property var dailyTokens: []
    property var fineTokens: []
    // Throughput rates (tok/h, from local_stats.py)
    property real rateOutput5m: 0     // output only (Claude's generated text)
    property real rateOutput30m: 0
    property real rateAll5m: 0        // everything incl. cache_read (quota impact)
    property real rateAll30m: 0
    property var recentSessions: []
    property var activeSessionsList: []
    property var modelsUsed: ({})

    // ── Session window ──
    property int sessionNumber: 0
    property int sessionTotal: 5
    property double sessionEndTs: 0
    property int sessionInputLimit: 0
    property int sessionOutputLimit: 0
    property int sessionInputUsed: 0
    property int sessionOutputUsed: 0

    // ── Gemini state ──
    property bool geminiLoading: false
    property bool geminiOk: false
    property string geminiPlan: ""
    property string geminiError: ""
    property int geminiReqLimit: 0
    property int geminiReqRemaining: 0
    property int geminiTokLimit: 0
    property int geminiTokRemaining: 0
    property var geminiModels: []
    property bool geminiRateLimited: false

    // Tick counter for session countdown (only when popup open)
    property int tick: 0
    Timer {
        interval: 30000
        running: root.expanded || root.onDesktop
        repeat: true
        onTriggered: root.tick++
    }

    switchWidth: onDesktop ? 0 : Kirigami.Units.gridUnit * 30
    switchHeight: onDesktop ? 0 : Kirigami.Units.gridUnit * 36

    // ── Data sources ──
    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            var stdout = data.stdout.trim()
            if (source.indexOf("gemini") >= 0) {
                if (stdout) { try { updateGemini(JSON.parse(stdout)) } catch(e) { console.log("Gemini parse error:", e) } }
                geminiLoading = false
            } else {
                if (stdout) { try { updateClaude(JSON.parse(stdout)) } catch(e) { console.log("Claude parse error:", e) } }
                loading = false
            }
            disconnectSource(source)
        }
    }

    // ── Realtime tachometer via /proc/pid/io ──
    //
    // Reads rchar (total bytes read, incl. network) from each session process.
    // Sum of all sessions' I/O vs baseline (heartbeat ~250 bps/session) detects streaming.
    // Smoothing: holds "active" for 3s after last detection to cover gaps.
    //
    property var _sessionPids: []       // PIDs of active sessions
    property var _prevRchar: ({})       // pid -> previous rchar value
    property real instantRate: 0        // activity factor 0-1 (0=idle, 1=streaming)
    property int _idleTicks: 0
    property int _activeSince: 0        // hold counter after last activity detection
    property real _lastMaxBps: 0        // raw I/O intensity for proportional needle
    property real _peakBps: 10000       // adaptive ceiling — starts at 10K, grows with observed peaks, decays slowly

    // Realtime rates: instantRate (0-1) * known rate from Python
    readonly property real instantOutputRate: instantRate * (rateOutput5m > 0 ? rateOutput5m : rateOutput30m)
    readonly property real instantAllRate: instantRate * (rateAll5m > 0 ? rateAll5m : rateAll30m)

    Plasma5Support.DataSource {
        id: ioSource
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            var stdout = data.stdout.trim()
            root._pollPending = false
            if (!stdout) { disconnectSource(source); return }

            // Parse grep output: "/proc/PID/io:rchar: VALUE"
            var lines = stdout.split("\n")
            var maxBps = 0
            var hasPrev = false
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i]
                var pidStart = line.indexOf("/proc/") + 6
                var pidEnd = line.indexOf("/io:")
                if (pidStart < 6 || pidEnd < 0) continue
                var pid = line.substring(pidStart, pidEnd)
                var rchar = parseInt(line.substring(line.lastIndexOf(" ") + 1))
                if (isNaN(rchar)) continue
                var prev = root._prevRchar[pid] || 0
                if (prev > 0) {
                    var bps = (rchar - prev)  // tick = 1s
                    if (bps > maxBps) maxBps = bps
                    hasPrev = true
                }
                root._prevRchar[pid] = rchar
            }
            if (!hasPrev) { disconnectSource(source); return }

            root._lastMaxBps = maxBps

            // Detect streaming: check if ANY single session has high I/O
            // Idle heartbeat: ~100-500 bps per session
            // User typing in terminal: ~500-2000 bps
            // API streaming: ~3000-50000+ bps
            var isActive = (maxBps > 2500)

            // Smoothing: once active, hold for 3 ticks (3s @ 1s)
            if (isActive) root._activeSince = 3
            else if (root._activeSince > 0) root._activeSince--
            var smoothedActive = root._activeSince > 0

            if (smoothedActive) {
                root._idleTicks = 0

                // Adaptive peak: instant rise on new highs, slow decay (0.5%/tick)
                if (maxBps > root._peakBps)
                    root._peakBps = maxBps
                else
                    root._peakBps = Math.max(5000, root._peakBps * 0.995)

                // Proportional: scale against observed peak
                var intensity = Math.min(1.0, Math.max(0.05, (maxBps - 2500) / (root._peakBps - 2500)))
                // Fast attack: jump toward target with strong lerp
                var target = 0.15 + intensity * 0.85
                if (root.instantRate < 0.2)
                    root.instantRate = target * 0.8  // initial kick
                else
                    root.instantRate += (target - root.instantRate) * 0.6
            } else {
                root._idleTicks++
                if (root._idleTicks <= 1) {
                    // 0-1s: hold briefly
                } else {
                    // Gradual decay — falls like a real needle with inertia
                    root.instantRate *= 0.45
                    if (root.instantRate < 0.01) root.instantRate = 0
                }
            }
            disconnectSource(source)
        }
    }

    property int _pollSeq: 0
    property bool _pollPending: false
    Timer {
        interval: 1000
        // Poll when popup is open, desktop widget, OR compact tacho mode needs live data
        running: root.activeSessions > 0 && root._sessionPids.length > 0 && (root.expanded || root.onDesktop || root.compactStyle === "tacho")
        repeat: true
        onTriggered: {
            if (root._pollPending) return  // don't stack requests
            root._pollPending = true
            // Alternate between 2 strings to force re-execution without unbounded accumulation
            root._pollSeq = 1 - root._pollSeq
            var cmd = "grep ^rchar:"
            for (var i = 0; i < root._sessionPids.length; i++)
                cmd += " /proc/" + root._sessionPids[i] + "/io"
            cmd += " 2>/dev/null #" + root._pollSeq
            ioSource.connectSource(cmd)
        }
    }

    // ── Timers ──
    Timer {
        interval: root.activeSessions > 0 ? 30000 : root.refreshInterval * 1000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: refreshAll()
    }

    // ── Data functions ──
    function refreshAll() {
        loading = true
        var claudeScript = Qt.resolvedUrl("../code/local_stats.py").toString().replace("file://", "")
        var limitArgs = ""
        if (dailyInputLimitM > 0) limitArgs += " --input-limit " + dailyInputLimitM
        if (dailyOutputLimitM > 0) limitArgs += " --output-limit " + dailyOutputLimitM
        executable.connectSource("python3 " + claudeScript + limitArgs)

        if (geminiApiKey) {
            geminiLoading = true
            var geminiScript = Qt.resolvedUrl("../code/gemini_stats.py").toString().replace("file://", "")
            executable.connectSource("python3 " + geminiScript + " " + geminiApiKey)
        }
    }

    function updateClaude(s) {
        subType = s.subscription.type || "unknown"
        tierName = Api.tierLabel(s.subscription.tier)
        activeSessions = s.sessions.active || 0
        promptsToday = s.prompts.today || 0
        promptsWeek = s.prompts.week || 0
        promptsMonth = s.prompts.month || 0
        if (s.limits) {
            hasLimits = true
            limInTokPerDay = s.limits.input_tokens_per_day || 0
            limOutTokPerDay = s.limits.output_tokens_per_day || 0
        }
        tokInToday = (s.tokens.today.input || 0) + (s.tokens.today.cache_read || 0) + (s.tokens.today.cache_create || 0)
        tokOutToday = s.tokens.today.output || 0
        tokCacheReadToday = s.tokens.today.cache_read || 0
        tokCacheCreateToday = s.tokens.today.cache_create || 0
        tokInWeek = (s.tokens.week.input || 0) + (s.tokens.week.cache_read || 0) + (s.tokens.week.cache_create || 0)
        tokOutWeek = s.tokens.week.output || 0
        tokInMonth = (s.tokens.month.input || 0) + (s.tokens.month.cache_read || 0) + (s.tokens.month.cache_create || 0)
        tokOutMonth = s.tokens.month.output || 0
        estCostWeek = s.est_cost.week || 0
        estCostTotal = s.est_cost.total || 0
        dailyTokens = s.daily_tokens || []
        fineTokens = s.fine_tokens || []
        if (s.throughput) {
            rateOutput5m = s.throughput.rate_output_5m || 0
            rateOutput30m = s.throughput.rate_output_30m || 0
            rateAll5m = s.throughput.rate_all_5m || 0
            rateAll30m = s.throughput.rate_all_30m || 0
        }
        recentSessions = s.recent_sessions || []
        activeSessionsList = s.active_sessions || []
        modelsUsed = s.models_used || {}

        // Extract PIDs for realtime /proc/pid/io monitoring
        var pids = []
        var sessions = s.active_sessions || []
        for (var i = 0; i < sessions.length; i++) {
            if (sessions[i].pid) pids.push(String(sessions[i].pid))
        }
        // Only reset rchar baseline when PIDs actually change
        var pidsChanged = pids.length !== _sessionPids.length
        if (!pidsChanged) {
            for (var j = 0; j < pids.length; j++) {
                if (pids[j] !== _sessionPids[j]) { pidsChanged = true; break }
            }
        }
        _sessionPids = pids
        if (pidsChanged) _prevRchar = {}

        if (s.session_window) {
            sessionNumber = s.session_window.number || 0
            sessionTotal = s.session_window.total || 5
            sessionEndTs = s.session_window.end_ts || 0
            sessionInputLimit = s.session_window.input_limit || 0
            sessionOutputLimit = s.session_window.output_limit || 0
            sessionInputUsed = s.session_window.input_used || 0
            sessionOutputUsed = s.session_window.output_used || 0
        }
    }

    function updateGemini(g) {
        geminiOk = g.ok || false
        geminiPlan = g.plan || "unknown"
        geminiError = g.error || ""
        geminiRateLimited = g.rate_limited || false
        var rl = g.rate_limits || {}
        geminiReqLimit = rl["x-ratelimit-limit-requests"] || 0
        geminiReqRemaining = rl["x-ratelimit-remaining-requests"] || 0
        geminiTokLimit = rl["x-ratelimit-limit-tokens"] || 0
        geminiTokRemaining = rl["x-ratelimit-remaining-tokens"] || 0
        geminiModels = g.models || []
    }

    // ─── Compact Representation ───
    compactRepresentation: Item {
        Layout.minimumWidth: compactRow.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.preferredWidth: compactRow.implicitWidth + Kirigami.Units.smallSpacing * 2

        RowLayout {
            id: compactRow
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            // ── Ring mode ──
            Rectangle {
                width: 8; height: 8; radius: 4
                visible: root.compactStyle === "ring"
                color: root.activeSessions > 0 ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor
                Layout.alignment: Qt.AlignVCenter
            }

            Canvas {
                id: miniRing
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                visible: root.compactStyle === "ring" && root.sessionInputLimit > 0
                property real pct: root.sessionInputLimit > 0 ? Math.min(1.0, root.sessionInputUsed / root.sessionInputLimit) : 0
                onPctChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d"); ctx.reset()
                    var cx = width / 2, cy = height / 2, r = Math.min(cx, cy) - 1
                    ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2 * Math.PI); ctx.lineWidth = 2
                    ctx.strokeStyle = Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15); ctx.stroke()
                    if (pct > 0) {
                        ctx.beginPath(); ctx.arc(cx, cy, r, -Math.PI/2, -Math.PI/2 + 2*Math.PI*pct); ctx.lineWidth = 2
                        ctx.strokeStyle = pct > 0.9 ? Kirigami.Theme.negativeTextColor : pct > 0.7 ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.positiveTextColor; ctx.stroke()
                    }
                }
            }

            PlasmaComponents.Label {
                visible: root.compactStyle === "ring"
                text: {
                    if (root.sessionInputLimit > 0) return Math.round((root.sessionInputUsed / root.sessionInputLimit) * 100) + "%"
                    if (root.promptsToday > 0) return root.promptsToday + "p"
                    return root.tierName || "AI"
                }
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }

            // ── Tacho mode: just the gauge ──
            Item {
                id: miniTacho
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                visible: root.compactStyle === "tacho"

                property real pct: root.instantRate
                readonly property real _startRad: 3 * Math.PI / 4
                readonly property real _sweepRad: 3 * Math.PI / 2
                readonly property color _color: pct > 0.8 ? Kirigami.Theme.negativeTextColor
                                              : pct > 0.5 ? Kirigami.Theme.neutralTextColor
                                              : Kirigami.Theme.positiveTextColor

                Canvas {
                    id: miniTachoBg
                    anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d"); ctx.reset()
                        var cx = width / 2, cy = height / 2, r = Math.min(cx, cy) - 1
                        var startA = miniTacho._startRad, sweepA = miniTacho._sweepRad
                        var tc = Kirigami.Theme.textColor
                        ctx.beginPath(); ctx.arc(cx, cy, r, startA, startA + sweepA)
                        ctx.lineWidth = 2; ctx.lineCap = "butt"
                        ctx.strokeStyle = Qt.rgba(tc.r, tc.g, tc.b, 0.12); ctx.stroke()
                    }
                    Component.onCompleted: requestPaint()
                }

                Canvas {
                    id: miniTachoArc
                    anchors.fill: parent
                    property real pct: miniTacho.pct
                    onPctChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d"); ctx.reset()
                        if (pct <= 0) return
                        var cx = width / 2, cy = height / 2, r = Math.min(cx, cy) - 1
                        var startA = miniTacho._startRad, sweepA = miniTacho._sweepRad
                        ctx.beginPath(); ctx.arc(cx, cy, r, startA, startA + sweepA * pct)
                        ctx.lineWidth = 2; ctx.lineCap = "round"
                        ctx.strokeStyle = miniTacho._color; ctx.stroke()
                    }
                }

                // Needle
                Item {
                    x: parent.width / 2; y: parent.height / 2
                    rotation: (miniTacho._startRad + miniTacho._sweepRad * miniTacho.pct) * (180 / Math.PI) + 90
                    Behavior on rotation {
                        RotationAnimation {
                            duration: 350; easing.type: Easing.OutBack; easing.overshoot: 1.0
                            direction: RotationAnimation.Shortest
                        }
                    }
                    Rectangle {
                        x: -0.5; y: -(miniTacho.height / 2 - 4)
                        width: 1.5; height: miniTacho.height / 2 - 4
                        radius: 0.75
                        color: miniTacho._color
                    }
                }
                // Hub dot
                Rectangle {
                    x: parent.width / 2 - 1.5; y: parent.height / 2 - 1.5
                    width: 3; height: 3; radius: 1.5
                    color: Kirigami.Theme.textColor; opacity: 0.4
                }
            }
        }

        MouseArea { anchors.fill: parent; onClicked: root.expanded = !root.expanded }
    }

    // ─── Full Representation ───
    fullRepresentation: Item {
        Layout.preferredWidth: root.onDesktop ? -1 : Kirigami.Units.gridUnit * 32
        Layout.preferredHeight: root.onDesktop ? -1 : Kirigami.Units.gridUnit * 38
        Layout.minimumWidth: Kirigami.Units.gridUnit * 20
        Layout.minimumHeight: Kirigami.Units.gridUnit * 14
        Layout.fillWidth: root.onDesktop
        Layout.fillHeight: root.onDesktop

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            QQC2.TabBar {
                id: tabBar
                Layout.fillWidth: true

                QQC2.TabButton {
                    text: "Claude"
                    icon.name: "preferences-system-performance"
                }
                QQC2.TabButton {
                    text: "Gemini"
                    icon.name: "applications-science"
                    enabled: root.geminiApiKey !== ""
                    opacity: root.geminiApiKey !== "" ? 1.0 : 0.4
                }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: tabBar.currentIndex

                ClaudeTab { appRoot: root }
                GeminiTab { appRoot: root }
            }
        }
    }
}
