.pragma library

// Pure state selection for the collapsed-pill battery indicator (unit-testable outside QML).
// percent: 0..100, charging: bool. Charging wins over every percentage warning;
// then thresholds are checked in descending severity: <10, <20, <30, normal.
function batteryState(percent, charging) {
    if (charging) return "charging";
    if (percent < 10) return "critical";
    if (percent < 20) return "low";
    if (percent < 30) return "warning";
    return "normal";
}
