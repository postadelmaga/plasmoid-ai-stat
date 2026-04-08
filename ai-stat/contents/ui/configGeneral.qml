import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: configGeneral
    property string title: i18n("General")

    property alias cfg_refreshInterval: refreshSlider.value
    property alias cfg_popupHeightUnits: popupHeightSlider.value
    property alias cfg_showCosts: showCostsCheck.checked
    property alias cfg_monthlyBudget: budgetSpinBox.value
    property alias cfg_dailyInputLimitM: inputLimitSpinBox.value
    property alias cfg_dailyOutputLimitM: outputLimitSpinBox.value
    property alias cfg_geminiApiKey: geminiKeyField.text
    property string cfg_compactStyle: "ring"
    property string cfg_compactTargetService: "claude"
    property string cfg_compactTargetStat: "sessionInputPct"
    property alias cfg_pinPopupOpen: pinPopupOpenCheck.checked
    property alias cfg_enableClaude: enableClaudeCheck.checked
    property alias cfg_enableGeminiCli: enableGeminiCliCheck.checked
    property alias cfg_enableAntigravity: enableAntigravityCheck.checked
    property alias cfg_enableGeminiApi: enableGeminiApiCheck.checked
    property alias cfg_enableOpenCode: enableOpenCodeCheck.checked
    property alias cfg_enableCopilot: enableCopilotCheck.checked
    property alias cfg_enableKiro: enableKiroCheck.checked
    property int cfg_refreshIntervalDefault: 300
    property int cfg_popupHeightUnitsDefault: 40
    property bool cfg_showCostsDefault: true
    property real cfg_monthlyBudgetDefault: 100.0
    property int cfg_dailyInputLimitMDefault: 0
    property int cfg_dailyOutputLimitMDefault: 0
    property string cfg_geminiApiKeyDefault: ""
    property string cfg_compactStyleDefault: "ring"
    property string cfg_compactTargetServiceDefault: "claude"
    property string cfg_compactTargetStatDefault: "sessionInputPct"
    property bool cfg_pinPopupOpenDefault: false
    property bool cfg_enableClaudeDefault: true
    property bool cfg_enableGeminiCliDefault: true
    property bool cfg_enableAntigravityDefault: false
    property bool cfg_enableGeminiApiDefault: false
    property bool cfg_enableOpenCodeDefault: false
    property bool cfg_enableCopilotDefault: true
    property bool cfg_enableKiroDefault: true

    function enabledServiceModel() {
        var services = []
        if (enableClaudeCheck.checked) services.push({ value: "claude", text: i18n("Claude Code") })
        if (enableGeminiCliCheck.checked) services.push({ value: "gcli", text: i18n("Gemini CLI") })
        if (enableAntigravityCheck.checked) services.push({ value: "ag", text: i18n("Antigravity") })
        if (enableOpenCodeCheck.checked) services.push({ value: "oc", text: i18n("OpenCode") })
        if (enableGeminiApiCheck.checked) services.push({ value: "gemini", text: i18n("Gemini API") })
        if (enableCopilotCheck.checked) services.push({ value: "copilot", text: i18n("Copilot CLI") })
        if (enableKiroCheck.checked) services.push({ value: "kiro", text: i18n("Kiro") })
        return services
    }

    function statModelFor(serviceId) {
        if (serviceId === "claude") return [
            { value: "sessionInputPct", text: i18n("Session input usage (%)") },
            { value: "sessionUsagePct", text: i18n("Session total usage (%)") },
            { value: "activeSessions", text: i18n("Active sessions") },
            { value: "promptsToday", text: i18n("Prompts today") },
            { value: "promptsWeek", text: i18n("Prompts week") },
            { value: "promptsMonth", text: i18n("Prompts month") },
            { value: "tokInToday", text: i18n("Input tokens today") },
            { value: "tokOutToday", text: i18n("Output tokens today") },
            { value: "tokInWeek", text: i18n("Input tokens week") },
            { value: "tokOutWeek", text: i18n("Output tokens week") },
            { value: "tokInMonth", text: i18n("Input tokens month") },
            { value: "tokOutMonth", text: i18n("Output tokens month") },
            { value: "instantRate", text: i18n("Live activity") }
        ]
        if (serviceId === "gcli") return [
            { value: "reqUsedPct", text: i18n("Request quota used (%)") },
            { value: "reqToday", text: i18n("Requests today") },
            { value: "reqRemaining", text: i18n("Requests remaining") },
            { value: "activeSessions", text: i18n("Active sessions") },
            { value: "totalSessions", text: i18n("Total sessions") },
            { value: "promptsToday", text: i18n("Prompts today") },
            { value: "promptsWeek", text: i18n("Prompts week") },
            { value: "promptsMonth", text: i18n("Prompts month") },
            { value: "tokInToday", text: i18n("Input tokens today") },
            { value: "tokOutToday", text: i18n("Output tokens today") },
            { value: "tokInWeek", text: i18n("Input tokens week") },
            { value: "tokOutWeek", text: i18n("Output tokens week") },
            { value: "tokInMonth", text: i18n("Input tokens month") },
            { value: "tokOutMonth", text: i18n("Output tokens month") },
            { value: "instantRate", text: i18n("Live activity") }
        ]
        if (serviceId === "ag") return [
            { value: "promptCreditsPct", text: i18n("Prompt credits used (%)") },
            { value: "flowCreditsPct", text: i18n("Flow credits used (%)") },
            { value: "tokInToday", text: i18n("Input tokens today") },
            { value: "tokOutToday", text: i18n("Output tokens today") },
            { value: "tokInWeek", text: i18n("Input tokens week") },
            { value: "tokOutWeek", text: i18n("Output tokens week") },
            { value: "tokInMonth", text: i18n("Input tokens month") },
            { value: "tokOutMonth", text: i18n("Output tokens month") },
            { value: "instantRate", text: i18n("Live activity") }
        ]
        if (serviceId === "oc") return [
            { value: "activeSessions", text: i18n("Active sessions") },
            { value: "totalSessions", text: i18n("Total sessions") },
            { value: "tokInToday", text: i18n("Input tokens today") },
            { value: "tokOutToday", text: i18n("Output tokens today") },
            { value: "tokInWeek", text: i18n("Input tokens week") },
            { value: "tokOutWeek", text: i18n("Output tokens week") },
            { value: "tokInMonth", text: i18n("Input tokens month") },
            { value: "tokOutMonth", text: i18n("Output tokens month") },
            { value: "instantRate", text: i18n("Live activity") }
        ]
        if (serviceId === "gemini") return [
            { value: "reqRemaining", text: i18n("Requests remaining") },
            { value: "tokRemaining", text: i18n("Tokens remaining") },
            { value: "reqUsedPct", text: i18n("Request quota used (%)") },
            { value: "tokUsedPct", text: i18n("Token quota used (%)") },
            { value: "modelCount", text: i18n("Models available") }
        ]
        if (serviceId === "copilot") return [
            { value: "turnsToday", text: i18n("Turns today") },
            { value: "turnsWeek", text: i18n("Turns week") },
            { value: "turnsMonth", text: i18n("Turns month") },
            { value: "turnsTotal", text: i18n("Turns total") },
            { value: "sessionsActive", text: i18n("Active sessions") },
            { value: "sessionsToday", text: i18n("Sessions today") },
            { value: "sessionsWeek", text: i18n("Sessions week") },
            { value: "sessionsMonth", text: i18n("Sessions month") },
            { value: "sessionsTotal", text: i18n("Sessions total") }
        ]
        if (serviceId === "kiro") return [
            { value: "running", text: i18n("Running status") },
            { value: "powersInstalled", text: i18n("Powers installed") },
            { value: "extensions", text: i18n("Extensions active") },
            { value: "creditsUsed", text: i18n("Credits used") },
            { value: "creditsPct", text: i18n("Credits used (%)") }
        ]
        return []
    }

    function ensureCompactSelection() {
        var services = enabledServiceModel()
        if (services.length === 0) return
        var serviceFound = false
        for (var i = 0; i < services.length; i++) {
            if (services[i].value === cfg_compactTargetService) {
                serviceFound = true
                break
            }
        }
        if (!serviceFound) cfg_compactTargetService = services[0].value

        var stats = statModelFor(cfg_compactTargetService)
        if (stats.length === 0) return
        var statFound = false
        for (var j = 0; j < stats.length; j++) {
            if (stats[j].value === cfg_compactTargetStat) {
                statFound = true
                break
            }
        }
        if (!statFound) cfg_compactTargetStat = stats[0].value
    }

    function syncComboSelection(combo, targetValue) {
        if (!combo || !combo.model) return
        for (var i = 0; i < combo.model.length; i++) {
            if (combo.model[i].value === targetValue) {
                combo.currentIndex = i
                return
            }
        }
        combo.currentIndex = combo.model.length > 0 ? 0 : -1
    }

    Kirigami.FormLayout {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Services")
        }

        QQC2.CheckBox {
            id: enableClaudeCheck
            Kirigami.FormData.label: i18n("Claude Code:")
            text: i18n("Monitor ~/.claude/ usage")
        }

        QQC2.CheckBox {
            id: enableGeminiCliCheck
            Kirigami.FormData.label: i18n("Gemini CLI:")
            text: i18n("Monitor ~/.gemini/ usage")
        }

        QQC2.CheckBox {
            id: enableAntigravityCheck
            Kirigami.FormData.label: i18n("Antigravity:")
            text: i18n("Monitor via language server API")
        }

        QQC2.CheckBox {
            id: enableGeminiApiCheck
            Kirigami.FormData.label: i18n("Gemini API:")
            text: i18n("Check rate limits (requires API key)")
        }

        QQC2.CheckBox {
            id: enableOpenCodeCheck
            Kirigami.FormData.label: i18n("OpenCode:")
            text: i18n("Monitor ~/.local/share/opencode/ usage")
        }

        QQC2.CheckBox {
            id: enableCopilotCheck
            Kirigami.FormData.label: i18n("Copilot CLI:")
            text: i18n("Monitor ~/.copilot/ sessions")
        }

        QQC2.CheckBox {
            id: enableKiroCheck
            Kirigami.FormData.label: i18n("Kiro:")
            text: i18n("Monitor ~/.kiro/ powers & extensions")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Display")
        }

        QQC2.Slider {
            id: refreshSlider
            Kirigami.FormData.label: i18n("Refresh every %1s", Math.round(value))
            from: 60
            to: 900
            stepSize: 30
            Layout.fillWidth: true
        }

        QQC2.Slider {
            id: popupHeightSlider
            Kirigami.FormData.label: i18n("Popup height: %1", Math.round(value))
            from: 28
            to: 64
            stepSize: 1
            Layout.fillWidth: true
        }

        QQC2.ComboBox {
            id: compactStyleCombo
            Kirigami.FormData.label: i18n("Panel indicator:")
            model: [
                { value: "ring", text: i18n("Quota ring") },
                { value: "tacho", text: i18n("Tachometer") }
            ]
            textRole: "text"
            valueRole: "value"
            Component.onCompleted: currentIndex = cfg_compactStyle === "tacho" ? 1 : 0
            onActivated: cfg_compactStyle = model[index].value
        }

        QQC2.ComboBox {
            id: compactServiceCombo
            Kirigami.FormData.label: i18n("Compact service:")
            model: configGeneral.enabledServiceModel()
            textRole: "text"
            valueRole: "value"
            enabled: model.length > 0
            onActivated: {
                cfg_compactTargetService = model[index].value
                configGeneral.ensureCompactSelection()
                configGeneral.syncComboSelection(compactServiceCombo, cfg_compactTargetService)
                configGeneral.syncComboSelection(compactStatCombo, cfg_compactTargetStat)
            }
            onModelChanged: {
                configGeneral.ensureCompactSelection()
                configGeneral.syncComboSelection(compactServiceCombo, cfg_compactTargetService)
            }
            Component.onCompleted: {
                configGeneral.ensureCompactSelection()
                configGeneral.syncComboSelection(compactServiceCombo, cfg_compactTargetService)
            }
        }

        QQC2.ComboBox {
            id: compactStatCombo
            Kirigami.FormData.label: i18n("Compact stat:")
            model: configGeneral.statModelFor(cfg_compactTargetService)
            textRole: "text"
            valueRole: "value"
            enabled: model.length > 0
            onActivated: cfg_compactTargetStat = model[index].value
            onModelChanged: {
                configGeneral.ensureCompactSelection()
                configGeneral.syncComboSelection(compactStatCombo, cfg_compactTargetStat)
            }
            Component.onCompleted: {
                configGeneral.ensureCompactSelection()
                configGeneral.syncComboSelection(compactStatCombo, cfg_compactTargetStat)
            }
        }

        QQC2.CheckBox {
            id: pinPopupOpenCheck
            Kirigami.FormData.label: i18n("Popup behavior:")
            text: i18n("Pin popup open (sticky until unpinned)")
        }

        QQC2.CheckBox {
            id: showCostsCheck
            Kirigami.FormData.label: i18n("Show costs:")
            text: i18n("Display estimated cost info")
        }

        QQC2.SpinBox {
            id: budgetSpinBox
            Kirigami.FormData.label: i18n("Monthly budget ($):")
            from: 1
            to: 10000
            stepSize: 10
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Claude Code")
        }

        QQC2.Label {
            text: i18n("Tier auto-detected from ~/.claude/.credentials.json")
            wrapMode: Text.Wrap
            opacity: 0.6
            Layout.fillWidth: true
        }

        QQC2.SpinBox {
            id: inputLimitSpinBox
            Kirigami.FormData.label: i18n("Daily input limit (M tokens):")
            from: 0
            to: 9999
            stepSize: 10
        }

        QQC2.SpinBox {
            id: outputLimitSpinBox
            Kirigami.FormData.label: i18n("Daily output limit (M tokens):")
            from: 0
            to: 9999
            stepSize: 1
        }

        QQC2.Label {
            text: i18n("0 = auto-detect from tier. Override if limits seem wrong.")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.6
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Gemini")
        }

        QQC2.TextField {
            id: geminiKeyField
            Kirigami.FormData.label: i18n("Gemini API Key:")
            placeholderText: "AIzaSy..."
            echoMode: TextInput.Password
            Layout.fillWidth: true
        }

        QQC2.Label {
            text: i18n("Get your key at ai.google.dev. Used to check rate limits.")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.6
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
    }
}
