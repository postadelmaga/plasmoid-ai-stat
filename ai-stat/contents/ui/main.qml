import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

import "../code/formatters.js" as Api
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

    Plasmoid.backgroundHints: PlasmaCore.Types.StandardBackground | PlasmaCore.Types.ShadowBackground

    // ── Claude state ──
    property bool loading: false
    property string subType: ""
    property string tierName: ""
    property int activeSessions: 0
    property int promptsToday: 0
    property int promptsWeek: 0
    property int promptsMonth: 0
    property bool hasLimits: false
    property double limInTokPerDay: 0
    property double limOutTokPerDay: 0
    property double tokInToday: 0
    property double tokOutToday: 0
    property double tokCacheReadToday: 0
    property double tokCacheCreateToday: 0
    property double tokInWeek: 0
    property double tokOutWeek: 0
    property double tokInMonth: 0
    property double tokOutMonth: 0
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
    property double sessionInputLimit: 0
    property double sessionOutputLimit: 0
    property double sessionInputUsed: 0
    property double sessionOutputUsed: 0

    // ── Gemini API state ──
    property bool geminiLoading: false
    property bool geminiOk: false
    property string geminiPlan: ""
    property string geminiError: ""
    property double geminiReqLimit: 0
    property double geminiReqRemaining: 0
    property double geminiTokLimit: 0
    property double geminiTokRemaining: 0
    property var geminiModels: []
    property bool geminiRateLimited: false

    // ── Gemini CLI state ──
    property bool gcliLoading: false
    property string gcliAccount: ""
    property string gcliTier: ""
    property int gcliReqToday: 0
    property int gcliReqLimit: 1000
    property int gcliActiveSessions: 0
    property int gcliTotalSessions: 0
    property int gcliPromptsToday: 0
    property int gcliPromptsWeek: 0
    property int gcliPromptsMonth: 0
    property double gcliTokInToday: 0
    property double gcliTokOutToday: 0
    property double gcliTokInWeek: 0
    property double gcliTokOutWeek: 0
    property double gcliTokInMonth: 0
    property double gcliTokOutMonth: 0
    property double gcliTokCachedMonth: 0
    property double gcliTokThoughtsMonth: 0
    property var gcliDailyTokens: []
    property var gcliFineTokens: []
    property var gcliRecentSessions: []
    property var gcliActiveSessionsList: []
    property var gcliModelsUsed: ({})

    // ── Gemini CLI throughput & realtime ──
    property real gcliRateOutput5m: 0
    property real gcliRateOutput30m: 0
    property real gcliRateAll5m: 0
    property real gcliRateAll30m: 0
    property var _gcliPids: []
    property var _gcliPrevRchar: ({})
    property real gcliInstantRate: 0
    property int _gcliIdleTicks: 0
    property int _gcliActiveSince: 0
    property real _gcliPeakBps: 10000
    readonly property real gcliInstantAllRate: gcliInstantRate * (gcliRateAll5m > 0 ? gcliRateAll5m : gcliRateAll30m)
    readonly property real gcliInstantOutputRate: gcliInstantRate * (gcliRateOutput5m > 0 ? gcliRateOutput5m : gcliRateOutput30m)

    // ── Antigravity state ──
    property bool agLoading: false
    property bool agOk: false
    property string agPlan: ""
    property string agEmail: ""
    property double agPromptCredits: 0
    property double agPromptCreditsMax: 0
    property double agFlowCredits: 0
    property double agFlowCreditsMax: 0
    property double agTokInToday: 0
    property double agTokOutToday: 0
    property double agTokInWeek: 0
    property double agTokOutWeek: 0
    property double agTokInMonth: 0
    property double agTokOutMonth: 0
    property var agDailyTokens: []
    property var agFineTokens: []
    property var agRecentSessions: []
    property var agModelsUsed: ({})
    property var agModels: []
    property int agPid: 0

    // ── Antigravity throughput & realtime ──
    property real agRateAll5m: 0
    property real agRateAll30m: 0
    property real agRateOutput5m: 0
    property real agRateOutput30m: 0
    property real agInstantRate: 0
    readonly property real agInstantAllRate: agInstantRate * (agRateAll5m > 0 ? agRateAll5m : agRateAll30m)
    readonly property real agInstantOutputRate: agInstantRate * (agRateOutput5m > 0 ? agRateOutput5m : agRateOutput30m)
    property bool _agPollPending: false
    property string _agPort: ""
    property string _agCsrf: ""
    property int _agPrevSteps: 0

    Plasma5Support.DataSource {
        id: agPollSource
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            root._agPollPending = false
            var stdout = data.stdout.trim()
            if (!stdout || stdout.charAt(0) !== '{') { disconnectSource(source); return }
            try {
                var resp = JSON.parse(stdout)
                var trajs = resp.trajectorySummaries || {}
                var isRunning = false
                var totalSteps = 0
                for (var cid in trajs) {
                    var t = trajs[cid]
                    totalSteps += (t.stepCount || 0)
                    if (t.status && t.status.indexOf("RUNNING") >= 0) isRunning = true
                }
                var stepDelta = Math.max(0, totalSteps - root._agPrevSteps)
                root._agPrevSteps = totalSteps

                var target = 0
                if (isRunning) target = Math.min(1.0, stepDelta / 5.0)
                else if (stepDelta > 0) target = 0.3

                if (target > 0) {
                    if (root.agInstantRate < 0.1) root.agInstantRate = target * 0.7
                    else root.agInstantRate += (target - root.agInstantRate) * 0.5
                } else {
                    root.agInstantRate *= 0.4
                    if (root.agInstantRate < 0.01) root.agInstantRate = 0
                }
            } catch(e) {}
            disconnectSource(source)
        }
    }
    property int _agPollSeq: 0
    Timer {
        interval: 2000
        running: root.agOk && root._agPort !== "" && (root.expanded || root.onDesktop)
        repeat: true
        onTriggered: {
            if (root._agPollPending || !root._agPort || !root._agCsrf) return
            root._agPollPending = true
            root._agPollSeq = 1 - root._agPollSeq
            var cmd = "curl -s -m 2 -X POST http://127.0.0.1:" + root._agPort
                + "/exa.language_server_pb.LanguageServerService/GetAllCascadeTrajectories"
                + " -H 'X-Codeium-Csrf-Token: " + root._agCsrf + "'"
                + " -H 'Content-Type: application/json' -d '{}'"
                + " #" + root._agPollSeq
            agPollSource.connectSource(cmd)
        }
    }

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
            if (source.indexOf("antigravity_stats") >= 0) {
                if (stdout) { try { updateAntigravity(JSON.parse(stdout)) } catch(e) { console.log("Antigravity parse error:", e) } }
                agLoading = false
            } else if (source.indexOf("gemini_local_stats") >= 0) {
                if (stdout) { try { updateGeminiCli(JSON.parse(stdout)) } catch(e) { console.log("GeminiCLI parse error:", e) } }
                gcliLoading = false
            } else if (source.indexOf("gemini") >= 0) {
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
            // Split by Claude vs Gemini PIDs
            var lines = stdout.split("\n")
            var claudeMaxBps = 0, gcliMaxBps = 0
            var claudeHasPrev = false, gcliHasPrev = false

            // Build PID lookup sets
            var claudePidSet = {}
            for (var ci = 0; ci < root._sessionPids.length; ci++) claudePidSet[root._sessionPids[ci]] = true
            var gcliPidSet = {}
            for (var gi = 0; gi < root._gcliPids.length; gi++) gcliPidSet[root._gcliPids[gi]] = true

            for (var i = 0; i < lines.length; i++) {
                var line = lines[i]
                var pidStart = line.indexOf("/proc/") + 6
                var pidEnd = line.indexOf("/io:")
                if (pidStart < 6 || pidEnd < 0) continue
                var pid = line.substring(pidStart, pidEnd)
                var rchar = parseInt(line.substring(line.lastIndexOf(" ") + 1))
                if (isNaN(rchar)) continue

                var isClaude = claudePidSet[pid] || false
                var isGcli = gcliPidSet[pid] || false
                var prevMap = isClaude ? root._prevRchar : root._gcliPrevRchar
                var prev = prevMap[pid] || 0

                if (prev > 0) {
                    var bps = (rchar - prev)
                    if (isClaude) { if (bps > claudeMaxBps) claudeMaxBps = bps; claudeHasPrev = true }
                    if (isGcli) { if (bps > gcliMaxBps) gcliMaxBps = bps; gcliHasPrev = true }
                }
                prevMap[pid] = rchar
            }

            // Update Claude rate
            if (claudeHasPrev) _updateRate(claudeMaxBps, "_activeSince", "_idleTicks", "_peakBps", "instantRate")
            else if (root._sessionPids.length === 0) { root.instantRate = 0 }

            // Update Gemini CLI rate
            if (gcliHasPrev) _updateRate(gcliMaxBps, "_gcliActiveSince", "_gcliIdleTicks", "_gcliPeakBps", "gcliInstantRate")
            else if (root._gcliPids.length === 0) { root.gcliInstantRate = 0 }


            disconnectSource(source)
        }
    }

    function _updateRate(maxBps, activeSinceProp, idleTicksProp, peakBpsProp, rateProp) {
        var isActive = (maxBps > 1000)

        if (isActive) root[activeSinceProp] = 3
        else if (root[activeSinceProp] > 0) root[activeSinceProp]--
        var smoothedActive = root[activeSinceProp] > 0

        if (smoothedActive) {
            root[idleTicksProp] = 0
            if (maxBps > root[peakBpsProp]) root[peakBpsProp] = maxBps
            else root[peakBpsProp] = Math.max(10000, root[peakBpsProp] * 0.995)
            var intensity = Math.min(1.0, Math.max(0.05, (maxBps - 1000) / (root[peakBpsProp] - 100)))
            var target = 0.15 + intensity * 0.85
            if (root[rateProp] < 0.2) root[rateProp] = target * 0.8
            else root[rateProp] += (target - root[rateProp]) * 0.6
        } else {
            root[idleTicksProp]++
            if (root[idleTicksProp] > 1) {
                root[rateProp] *= 0.45
                if (root[rateProp] < 0.01) root[rateProp] = 0
            }
        }
    }

    property int _pollSeq: 0
    property bool _pollPending: false
    property bool _hasAnyPids: root._sessionPids.length > 0 || root._gcliPids.length > 0
    Timer {
        interval: 1000
        running: root._hasAnyPids && (root.expanded || root.onDesktop || root.compactStyle === "tacho")
        repeat: true
        onTriggered: {
            if (root._pollPending) return
            var allPids = root._sessionPids.concat(root._gcliPids)
            if (allPids.length === 0) return
            root._pollPending = true
            root._pollSeq = 1 - root._pollSeq
            var cmd = "grep -H ^rchar:"
            for (var i = 0; i < allPids.length; i++)
                cmd += " /proc/" + allPids[i] + "/io"
            cmd += " 2>/dev/null #" + root._pollSeq
            ioSource.connectSource(cmd)
        }
    }

    // ── Timers ──
    Timer {
        interval: (root.activeSessions > 0 || root.gcliActiveSessions > 0) ? 30000 : root.refreshInterval * 1000
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

        gcliLoading = true
        var gcliScript = Qt.resolvedUrl("../code/gemini_local_stats.py").toString().replace("file://", "")
        executable.connectSource("python3 " + gcliScript)

        agLoading = true
        var agScript = Qt.resolvedUrl("../code/antigravity_stats.py").toString().replace("file://", "")
        executable.connectSource("python3 " + agScript)
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

    function updateGeminiCli(g) {
        gcliAccount = g.account || ""
        gcliTier = g.tier || "Free"
        var quota = g.quota || {}
        gcliReqToday = quota.requests_today || 0
        gcliReqLimit = quota.requests_limit || 1000
        gcliActiveSessions = (g.sessions || {}).active || 0
        gcliTotalSessions = (g.sessions || {}).total || 0
        gcliPromptsToday = (g.prompts || {}).today || 0
        gcliPromptsWeek = (g.prompts || {}).week || 0
        gcliPromptsMonth = (g.prompts || {}).month || 0
        var t = g.tokens || {}
        var td = t.today || {}; var tw = t.week || {}; var tm = t.month || {}
        gcliTokInToday = (td.input || 0) + (td.cached || 0) + (td.thoughts || 0) + (td.tool || 0)
        gcliTokOutToday = td.output || 0
        gcliTokInWeek = (tw.input || 0) + (tw.cached || 0) + (tw.thoughts || 0) + (tw.tool || 0)
        gcliTokOutWeek = tw.output || 0
        gcliTokInMonth = (tm.input || 0) + (tm.cached || 0) + (tm.thoughts || 0) + (tm.tool || 0)
        gcliTokOutMonth = tm.output || 0
        gcliTokCachedMonth = tm.cached || 0
        gcliTokThoughtsMonth = tm.thoughts || 0
        if (g.throughput) {
            gcliRateOutput5m = g.throughput.rate_output_5m || 0
            gcliRateOutput30m = g.throughput.rate_output_30m || 0
            gcliRateAll5m = g.throughput.rate_all_5m || 0
            gcliRateAll30m = g.throughput.rate_all_30m || 0
        }
        gcliDailyTokens = g.daily_tokens || []
        gcliFineTokens = g.fine_tokens || []
        gcliRecentSessions = g.recent_sessions || []
        gcliActiveSessionsList = g.active_sessions || []
        gcliModelsUsed = g.models_used || {}

        // Extract PIDs for I/O polling (parent + children)
        var pids = []
        var sessions = g.active_sessions || []
        for (var i = 0; i < sessions.length; i++) {
            var spids = sessions[i].pids || []
            for (var k = 0; k < spids.length; k++) pids.push(String(spids[k]))
            if (spids.length === 0 && sessions[i].pid) pids.push(String(sessions[i].pid))
        }
        var pidsChanged = pids.length !== _gcliPids.length
        if (!pidsChanged) {
            for (var j = 0; j < pids.length; j++) {
                if (pids[j] !== _gcliPids[j]) { pidsChanged = true; break }
            }
        }
        _gcliPids = pids
        if (pidsChanged) _gcliPrevRchar = {}
    }

    function updateAntigravity(a) {
        agOk = a.ok || false
        agPlan = a.plan || ""
        agEmail = a.email || ""
        var cr = a.credits || {}
        agPromptCredits = cr.prompt || 0
        agPromptCreditsMax = cr.prompt_max || 0
        agFlowCredits = cr.flow || 0
        agFlowCreditsMax = cr.flow_max || 0
        var t = a.tokens || {}
        var td = t.today || {}; var tw = t.week || {}; var tm = t.month || {}
        agTokInToday = td.input || 0
        agTokOutToday = td.output || 0
        agTokInWeek = tw.input || 0
        agTokOutWeek = tw.output || 0
        agTokInMonth = tm.input || 0
        agTokOutMonth = tm.output || 0
        if (a.throughput) {
            agRateOutput5m = a.throughput.rate_output_5m || 0
            agRateOutput30m = a.throughput.rate_output_30m || 0
            agRateAll5m = a.throughput.rate_all_5m || 0
            agRateAll30m = a.throughput.rate_all_30m || 0
        }
        agDailyTokens = a.daily_tokens || []
        agFineTokens = a.fine_tokens || []
        agRecentSessions = a.recent_sessions || []
        agModelsUsed = a.models_used || {}
        agModels = a.models || []
        agPid = a.pid || 0
        // Save connection info for lightweight curl polling
        if (a.port) _agPort = String(a.port)
        if (a.csrf) _agCsrf = a.csrf
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

        Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
        Kirigami.Theme.inherit: false


        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            QQC2.TabBar {
                id: tabBar
                Layout.fillWidth: true
                // QQC2 breeze style hardcodes Header colorSet — override it
                Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
                Kirigami.Theme.inherit: false

                QQC2.TabButton {
                    text: "Claude"
                    icon.name: "preferences-system-performance"
                    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
                    Kirigami.Theme.inherit: false
                }
                QQC2.TabButton {
                    text: "Gemini CLI"
                    icon.name: "akonadiconsole"
                }
                QQC2.TabButton {
                    text: "Antigravity"
                    icon.name: "code-context"
                }
                QQC2.TabButton {
                    text: "Gemini API"
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
                GeminiCliTab { appRoot: root }
                AntigravityTab { appRoot: root }
                GeminiTab { appRoot: root }
            }
        }
    }
}
