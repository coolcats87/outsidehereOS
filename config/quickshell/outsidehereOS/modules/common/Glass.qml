pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Apple "Liquid Glass" design tokens — the replacement for Material You in the
 * parts of the shell that have moved over (the island first).
 *
 * Nothing here is derived from the wallpaper: colours are Apple's fixed system
 * palette and label/fill hierarchy, in a light and a dark variant. The only
 * thing still read from the old theme is the light/dark switch itself.
 *
 * Widgets: GlassSurface, GlassButton, GlassIcon, GlassText, GlassSlider,
 * GlassTextField, GlassToolTip (modules/common/widgets).
 */
Singleton {
    id: root

    // ── Mode ──
    // Light / dark: the shell's own setting (saved in ~/.local/state/quickshell/user/appearance-mode),
    // dark until changed. setDark() also tells GTK/portal apps (color-scheme).
    property bool dark: true
    function setDark(d) {
        root.dark = d;
        modeFile.setText(d ? "dark" : "light");
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", d ? "prefer-dark" : "prefer-light"]);
    }
    function toggleDark() { root.setDark(!root.dark); }
    onDarkChanged: Appearance.m3colors.darkmode = root.dark // the few leftover widgets still read this
    FileView {
        id: modeFile
        path: `${Directories.state}/user/appearance-mode`
        printErrors: false
        onLoaded: root.dark = modeFile.text().trim() !== "light"
    }

    // ── System colours (iOS/macOS 26, dark / light variants) ──
    readonly property color blue:   dark ? "#0A84FF" : "#007AFF"
    readonly property color green:  dark ? "#30D158" : "#34C759"
    readonly property color red:    dark ? "#FF453A" : "#FF3B30"
    readonly property color orange: dark ? "#FF9F0A" : "#FF9500"
    readonly property color yellow: dark ? "#FFD60A" : "#FFCC00"
    readonly property color purple: dark ? "#BF5AF2" : "#AF52DE"
    readonly property color pink:   dark ? "#FF375F" : "#FF2D55"
    readonly property color teal:   dark ? "#40CBE0" : "#30B0C7"
    readonly property color indigo: dark ? "#5E5CE6" : "#5856D6"
    readonly property color gray:   dark ? "#8E8E93" : "#8E8E93"

    readonly property color accent: blue
    readonly property color accentLabel: "#FFFFFF"

    // ── Labels ──
    readonly property color label:           dark ? "#FFFFFF" : "#000000"
    readonly property color secondaryLabel:  dark ? Qt.rgba(235/255, 235/255, 245/255, 0.62) : Qt.rgba(60/255, 60/255, 67/255, 0.62)
    readonly property color tertiaryLabel:   dark ? Qt.rgba(235/255, 235/255, 245/255, 0.32) : Qt.rgba(60/255, 60/255, 67/255, 0.32)
    readonly property color quaternaryLabel: dark ? Qt.rgba(235/255, 235/255, 245/255, 0.18) : Qt.rgba(60/255, 60/255, 67/255, 0.18)

    // ── Fills on glass (vibrant: white over dark glass, black over light glass) ──
    readonly property color fill:         dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.055)
    readonly property color fillHover:    dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.09)
    readonly property color fillPressed:  dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.13)
    readonly property color fillStrong:   dark ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0, 0, 0, 0.10)
    readonly property color track:        dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.08)
    readonly property color separator:    dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.10)
    // Platters: cards sitting inside a glass pane (notifications, now playing...)
    readonly property color platter:      dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.45)
    readonly property color platterHover: dark ? Qt.rgba(1, 1, 1, 0.11) : Qt.rgba(1, 1, 1, 0.62)
    // The bright fill of Control Center sliders
    readonly property color sliderFill:   "#FFFFFF"
    readonly property color sliderGlyph:  dark ? Qt.rgba(0, 0, 0, 0.62) : Qt.rgba(0, 0, 0, 0.55)

    // ── Glass materials (tint of the pane; the blur comes from Hyprland) ──
    // Keep alpha >= 0.3: hypr/custom/rules.lua blurs island layers with ignore_alpha 0.3.
    readonly property color regular: dark ? Qt.rgba(0.10, 0.10, 0.12, 0.46) : Qt.rgba(0.97, 0.97, 0.99, 0.52)
    readonly property color clear:   dark ? Qt.rgba(0.10, 0.10, 0.12, 0.34) : Qt.rgba(0.98, 0.98, 1.00, 0.36)
    readonly property color thick:   dark ? Qt.rgba(0.09, 0.09, 0.11, 0.62) : Qt.rgba(0.96, 0.96, 0.98, 0.70)
    readonly property color scrim:   dark ? Qt.rgba(0, 0, 0, 0.40) : Qt.rgba(1, 1, 1, 0.34)

    // Edge lighting
    readonly property color outline:     dark ? Qt.rgba(0, 0, 0, 0.35) : Qt.rgba(0, 0, 0, 0.10)
    readonly property real rimStrength:  dark ? 0.65 : 0.90
    readonly property real rimBase:      dark ? 0.10 : 0.45
    readonly property real glow:         dark ? 0.05 : 0.14
    readonly property real sheen:        dark ? 0.085 : 0.20
    readonly property real lightAngle:   -2.2  // radians: light from the top-left
    readonly property color shadow:      dark ? Qt.rgba(0, 0, 0, 0.34) : Qt.rgba(0, 0, 0, 0.16)

    // ── Shape ──
    // Concentric corners: an inner shape's radius = outer radius - the gap between them.
    function concentric(outerRadius, inset) { return Math.max(0, outerRadius - inset); }
    readonly property real radiusSmall: 10
    readonly property real radiusMedium: 16
    readonly property real radiusLarge: 22
    readonly property real radiusXL: 32

    // ── Type ──
    // Apple's SF Pro if it is installed, else Inter (its closest open relative), else the shell's font.
    readonly property var _families: Qt.fontFamilies()
    function _pick(candidates) {
        for (const f of candidates)
            if (root._families.indexOf(f) !== -1) return f;
        return Appearance.font.family.main;
    }
    readonly property string fontFamily: _pick(["SF Pro Display", "SF Pro Text", "SF Pro", "Inter Display", "Inter", "Inter Variable", "Google Sans Flex"])
    readonly property string fontRounded: _pick(["SF Pro Rounded", "SF Pro Display", "Inter Display", "Inter", "Google Sans Flex"])
    readonly property string fontMono: _pick(["SF Mono", "JetBrains Mono", "JetBrainsMono Nerd Font", "monospace"])
    readonly property string iconFamily: "Material Symbols Rounded" // closest installed stand-in for SF Symbols

    // Apple's text styles, sized for a desktop shell
    readonly property QtObject size: QtObject {
        readonly property int largeTitle: 34
        readonly property int title1: 28
        readonly property int title2: 22
        readonly property int title3: 19
        readonly property int headline: 15
        readonly property int body: 15
        readonly property int callout: 14
        readonly property int subheadline: 13
        readonly property int footnote: 12
        readonly property int caption: 11
    }

    // ── Motion ──
    // Springs, as Apple uses everywhere: interruptible (they keep their velocity when retargeted).
    // spring = stiffness-ish, damping < 1 = a little overshoot.
    readonly property QtObject spring: QtObject {
        // Island morph: lively, one soft overshoot
        readonly property real morphSpring: 3.4
        readonly property real morphDamping: 0.30
        readonly property real morphMass: 1.0
        // Controls / small things: quick, barely any bounce
        readonly property real snappySpring: 5.0
        readonly property real snappyDamping: 0.42
    }
    // Curves for NumberAnimation where a spring doesn't fit (fades, one-shot moves)
    readonly property QtObject curve: QtObject {
        readonly property list<real> bouncy: [0.30, 1.30, 0.40, 1.00, 1, 1]
        readonly property list<real> smooth: [0.25, 1.00, 0.30, 1.00, 1, 1]
        readonly property list<real> exit:   [0.40, 0.00, 0.85, 0.55, 1, 1]
    }
    readonly property QtObject duration: QtObject {
        readonly property int fast: 160
        readonly property int normal: 280
        readonly property int slow: 420
    }
}
