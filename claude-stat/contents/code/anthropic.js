.pragma library

function formatTokens(n) {
    if (n >= 1000000000) return (n / 1000000000).toFixed(1) + "B"
    if (n >= 1000000) return (n / 1000000).toFixed(1) + "M"
    if (n >= 1000) return (n / 1000).toFixed(1) + "K"
    return n.toString()
}

function formatCost(dollars) {
    if (dollars >= 100) return "$" + Math.round(dollars)
    if (dollars >= 10) return "$" + dollars.toFixed(1)
    return "$" + dollars.toFixed(2)
}

function formatDuration(minutes) {
    if (minutes >= 60) return Math.round(minutes / 60) + "h " + Math.round(minutes % 60) + "m"
    return Math.round(minutes) + "m"
}

function tierLabel(tier) {
    if (!tier) return ""
    if (tier.indexOf("max_5x") >= 0) return "Max 5x"
    if (tier.indexOf("max") >= 0) return "Max"
    if (tier.indexOf("pro") >= 0) return "Pro"
    if (tier.indexOf("team") >= 0) return "Team"
    return tier
}

function planIcon(subType) {
    if (subType === "max") return "\u2728"  // sparkles
    if (subType === "pro") return "\u26a1"  // zap
    if (subType === "team") return "\ud83d\udc65"
    return "\ud83e\udd16"
}

function shortModel(name) {
    if (!name) return "?"
    if (name.indexOf("opus") >= 0) return "Opus"
    if (name.indexOf("sonnet") >= 0) return "Sonnet"
    if (name.indexOf("haiku") >= 0) return "Haiku"
    return name.substring(0, 12)
}
