#version 440
// Liquid-glass pane for the Apple look (modules/common/widgets/GlassSurface.qml).
// One pass, any size, no textures: the blur of what is behind comes from the
// compositor (Hyprland layer rule); this draws everything on top of it:
//   - the tint (the glass's body colour)
//   - a thin rim lit from the top-left (and, dimmer, the bottom-right), like light
//     caught on the curved edge of a slab of glass
//   - a soft inner bevel glow along the edge (the glass's thickness)
//   - a faint sheen fading down from the top
//   - a hairline outline that keeps the pane apart from bright backgrounds
//   - a soft drop shadow, outside the pane only (it never darkens the glass)
//
// Compile: /usr/lib/qt6/bin/qsb --glsl "100 es,120,150" -o glasssurface.frag.qsb glasssurface.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;      // px of the whole effect item (pane + shadow padding on every side)
    float pad;          // px of shadow padding around the pane
    float radius;       // px corner radius of the pane
    vec4 tint;          // body colour, straight alpha
    vec4 outline;       // hairline colour at the very edge, straight alpha
    float rimWidth;     // px of the lit rim
    float rimStrength;  // brightness of the lit rim (0..1+)
    float rimBase;      // brightness of the rim where the light doesn't hit it
    float glow;         // brightness of the inner bevel glow
    float bezel;        // px the bevel glow reaches in from the edge
    float sheen;        // brightness of the top sheen
    float lightAngle;   // radians; direction the light comes from (screen space, y down)
    vec4 shadowColor;   // straight alpha
    float shadowBlur;   // px
    float shadowOffsetY;// px
};

// Signed distance to a rounded box centred on the origin
float sdRoundBox(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - halfSize + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// Outward normal of the rounded box at p
vec2 roundBoxNormal(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - halfSize + r;
    vec2 n;
    if (q.x > 0.0 && q.y > 0.0) n = normalize(q);
    else n = (q.x > q.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    return n * sign(p + 1e-6);
}

// "a over b", premultiplied
vec4 over(vec4 a, vec4 b) {
    return a + b * (1.0 - a.a);
}

void main() {
    vec2 px = qt_TexCoord0 * itemSize;
    vec2 paneSize = itemSize - 2.0 * pad;
    vec2 halfSize = paneSize * 0.5;
    vec2 centre = itemSize * 0.5;
    float r = min(radius, min(halfSize.x, halfSize.y));
    vec2 p = px - centre;

    float d = sdRoundBox(p, halfSize, r);
    float inside = clamp(0.5 - d, 0.0, 1.0);   // antialiased coverage of the pane
    float t = max(-d, 0.0);                    // px in from the edge

    // ── Shadow (outside the pane only) ──
    vec4 col = vec4(0.0);
    if (shadowColor.a > 0.0 && shadowBlur > 0.0) {
        float ds = sdRoundBox(p - vec2(0.0, shadowOffsetY), halfSize, r);
        float s = 1.0 - smoothstep(-shadowBlur * 0.35, shadowBlur, ds);
        s *= s;
        float a = shadowColor.a * s * (1.0 - inside);
        col = vec4(shadowColor.rgb * a, a);
    }

    if (inside <= 0.0) {
        fragColor = col * qt_Opacity;
        return;
    }

    // ── Glass body ──
    vec4 body = vec4(tint.rgb * tint.a, tint.a);

    // Light on the edge: strongest where the edge faces the light, weaker on the opposite side
    vec2 n = roundBoxNormal(p, halfSize, r);
    vec2 L = vec2(cos(lightAngle), sin(lightAngle));
    float facing = max(dot(n, L), 0.0);
    float back = max(dot(n, -L), 0.0);
    float spec = pow(facing, 1.6) + 0.18 * pow(back, 2.4);

    // Inner bevel: a glow that fades in from the edge
    float bevel = 1.0 - smoothstep(0.0, max(bezel, 0.5), t);
    float glowA = glow * bevel * bevel * (0.15 + 0.85 * spec);

    // Gloss: a bright reflection on the upper part of the pane, fading out smoothly
    // (strong near the top edge, gone by about the middle), like light on polished glass
    float yIn = clamp((px.y - pad) / max(min(paneSize.y * 0.55, 140.0), 1.0), 0.0, 1.0);
    float sheenA = sheen * pow(1.0 - yIn, 2.2);

    // Rim: a thin band right at the edge
    float rimBand = 1.0 - smoothstep(rimWidth - 0.5, rimWidth + 0.5, t);
    float rimA = rimBand * clamp(rimBase + rimStrength * spec, 0.0, 1.0);

    // Hairline outline: the outermost pixel
    float lineBand = 1.0 - smoothstep(0.0, 1.0, t);
    vec4 line = vec4(outline.rgb, 1.0) * outline.a * lineBand;

    float whiteA = clamp(glowA + sheenA, 0.0, 1.0);
    vec4 glass = over(vec4(vec3(whiteA), whiteA), body);
    glass = over(line, glass);
    glass = over(vec4(vec3(rimA), rimA), glass);

    col = over(glass * inside, col);
    fragColor = col * qt_Opacity;
}
