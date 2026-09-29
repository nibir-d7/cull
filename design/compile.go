package design

import (
	"bytes"
	"fmt"
	"sort"
	"strings"
	"unicode"
)

const dartHeader = `// GENERATED FILE -- DO NOT EDIT.
//
// Source:    design/tokens.json
// Generator: cmd/designtool (go run ./cmd/designtool compile)
// Regenerate: go run ./cmd/designtool compile
//
// This is the only place design values are allowed to exist. If a widget needs
// a colour, a size, a radius or a duration, add a token and recompile -- do not
// write a literal here or in any widget.

`

func DartName(key string) string {
	parts := strings.FieldsFunc(key, func(r rune) bool {
		return !unicode.IsLetter(r) && !unicode.IsDigit(r)
	})
	if len(parts) == 0 {
		return "unnamed"
	}
	out := parts[0]
	for _, p := range parts[1:] {
		if p == "" {
			continue
		}
		out += strings.ToUpper(p[:1]) + p[1:]
	}

	if out[0] >= '0' && out[0] <= '9' {
		out = "n" + out
	}
	return out
}

func ClassName(key string) string {
	n := DartName(key)
	return strings.ToUpper(n[:1]) + n[1:]
}

func CompileDart(t *Tokens) ([]byte, error) {
	var b bytes.Buffer
	b.WriteString(dartHeader)
	b.WriteString("import 'package:flutter/animation.dart';\nimport 'package:flutter/painting.dart';\n\n")
	b.WriteString("/// CULL design tokens. Generated; see design/tokens.json.\n")
	b.WriteString("abstract final class CullTokens {\n")

	b.WriteString("\n  // -- Colour ---\n")
	names := t.Color.Names()
	sort.Strings(names)
	b.WriteString("  // Charcoal, never pure black. Ink is warm, never #FFFFFF.\n")
	for _, n := range names {
		v := mustColor(t, n)
		c := MustHex(v.Value)
		alpha := int(v.Alpha*255 + 0.5)
		fmt.Fprintf(&b, "  static const Color %s = Color(0x%02X%02X%02X%02X);",
			DartName(n), alpha, c.R, c.G, c.B)
		if role := singleLine(v.Role); role != "" {
			fmt.Fprintf(&b, " // %s", role)
		}
		b.WriteString("\n")
	}

	b.WriteString("\n  // -- HoardScore bands --\n")
	for _, n := range t.BandNames() {
		band := t.HoardBand[n]
		c := MustHex(band.Value)
		fmt.Fprintf(&b, "  static const Color hoard%s = Color(0xFF%02X%02X%02X); // %s\n",
			ClassName(n), c.R, c.G, c.B, band.Label)
	}

	b.WriteString("\n  // -- Categories --\n")
	b.WriteString("  /// Hue is meaning, but never the only meaning: every pill carries its\n")
	b.WriteString("  /// label text, so the hue is redundant reinforcement.\n")
	for _, k := range t.CategoryNames() {
		cat := t.Category[k]
		c := MustHex(cat.Value)
		s := MustHex(cat.Surface)
		fmt.Fprintf(&b, "  static const Color cat%s = Color(0xFF%02X%02X%02X);\n", ClassName(k), c.R, c.G, c.B)
		fmt.Fprintf(&b, "  static const Color cat%sSurface = Color(0xFF%02X%02X%02X);\n", ClassName(k), s.R, s.G, s.B)
		fmt.Fprintf(&b, "  static const double cat%sTint = %s;\n", ClassName(k), fmtFloat(cat.TintAlpha))
		fmt.Fprintf(&b, "  static const String cat%sLabel = %q;\n", ClassName(k), cat.Label)
	}

	b.WriteString("\n  // -- Space (4pt grid) ---\n")
	for _, k := range sortedKeys(t.Space) {
		fmt.Fprintf(&b, "  static const double space%s = %s;\n", ClassName(k), fmtFloat(t.Space[k]))
	}
	b.WriteString("\n  // -- Radius (40px+ on primary surfaces) ---\n")
	for _, k := range sortedKeys(t.Radius) {
		fmt.Fprintf(&b, "  static const double radius%s = %s;\n", ClassName(k), fmtFloat(t.Radius[k]))
	}

	b.WriteString("\n  // -- Type ---\n")
	b.WriteString("  // Serif headlines, sans body, mono receipts. Editorial, not systematic.\n")
	for _, k := range sortedKeys(t.Type.Font) {
		f := t.Type.Font[k]
		fmt.Fprintf(&b, "  static const String font%s = %q;\n", ClassName(k), f.Family)
		fmt.Fprintf(&b, "  static const List<String> font%sFallback = %s;\n", ClassName(k), dartStringList(f.Fallback))
	}
	b.WriteString("\n")
	for _, k := range sortedKeys(t.Type.Scale) {
		s := t.Type.Scale[k]
		fmt.Fprintf(&b, "  static const double type%sSize = %s;\n", ClassName(k), fmtFloat(s.Size))
		fmt.Fprintf(&b, "  static const double type%sLineHeight = %s;\n", ClassName(k), fmtFloat(s.LineHeight))
		fmt.Fprintf(&b, "  static const int type%sWeight = %d;\n", ClassName(k), s.Weight)
		fmt.Fprintf(&b, "  static const double type%sTracking = %s;\n", ClassName(k), fmtFloat(s.Tracking))
		fmt.Fprintf(&b, "  static const String type%sFont = font%s;\n", ClassName(k), ClassName(s.Font))
	}

	b.WriteString("\n  // -- Glass (blurred fill + lighter border, or it is a flat panel) ---\n")
	for _, k := range sortedKeys(t.Glass) {
		g := t.Glass[k]
		fmt.Fprintf(&b, "  static const double glass%sBlur = %s;\n", ClassName(k), fmtFloat(g.Blur))
		fmt.Fprintf(&b, "  static const double glass%sOpacity = %s;\n", ClassName(k), fmtFloat(g.Opacity))
		fmt.Fprintf(&b, "  static const double glass%sBorderAlpha = %s;\n", ClassName(k), fmtFloat(g.BorderAlpha))
		fmt.Fprintf(&b, "  static const Color glass%sSurface = %s;\n", ClassName(k), DartName(g.Surface))
		fmt.Fprintf(&b, "  static const List<BoxShadow> glass%sShadow = %s;\n\n", ClassName(k), dartShadow(t.Shadow[g.Shadow]))
	}

	b.WriteString("  // -- Motion ---\n")
	b.WriteString("  // Every tier has a reduced-motion duration. Honour prefers-reduced-motion\n")
	b.WriteString("  // by using the reduced value; the value still renders, immediately.\n")
	for _, tier := range []struct {
		name string
		m    MotionTier
	}{{"instant", t.Motion.Instant}, {"settle", t.Motion.Settle}, {"dramatic", t.Motion.Dramatic}} {
		n := ClassName(tier.name)
		fmt.Fprintf(&b, "  static const Duration motion%s = Duration(milliseconds: %d);\n", n, int(tier.m.Duration))
		fmt.Fprintf(&b, "  static const Duration motion%sReduced = Duration(milliseconds: %d);\n", n, int(tier.m.Reduced))
		fmt.Fprintf(&b, "  static const Curve motion%sCurve = Curves.easeInOut; // %s\n\n", n, tier.m.Easing)
	}
	for _, k := range sortedKeys(t.Motion.Easing) {
		e := t.Motion.Easing[k]
		pts := make([]string, 4)
		for i, v := range e.Cubic {
			pts[i] = fmtFloat(v)
		}
		fmt.Fprintf(&b, "  /// %s. %s\n", k, singleLine(e.Use))
		fmt.Fprintf(&b, "  static const Cubic curve%s = Cubic(%s, %s, %s, %s);\n",
			ClassName(k), pts[0], pts[1], pts[2], pts[3])
	}

	b.WriteString("\n  // -- Texture & layout ---\n")
	fmt.Fprintf(&b, "  static const double grainOpacity = %s;\n", fmtFloat(t.Grain.Opacity))
	fmt.Fprintf(&b, "  static const int grainTileSize = %d;\n\n", t.Grain.Size)
	fmt.Fprintf(&b, "  static const double cardMinWidth = %s;\n", fmtFloat(t.Layout.CardMinWidth))
	fmt.Fprintf(&b, "  static const double cardMaxWidth = %s;\n", fmtFloat(t.Layout.CardMaxWidth))
	fmt.Fprintf(&b, "  static const int gridColumns = %d;\n", t.Layout.GridColumns)
	fmt.Fprintf(&b, "  static const double hoardIrregularity = %s;\n", fmtFloat(t.Layout.GrainIrregularity))
	fmt.Fprintf(&b, "  static const double pullQuoteMaxWidth = %s;\n", fmtFloat(t.Layout.PullQuoteMaxWidth))

	b.WriteString("\n  // -- Accessibility ---\n")
	fmt.Fprintf(&b, "  static const double minTouchTarget = %s;\n", fmtFloat(t.Access.MinTouchTarget))
	fmt.Fprintf(&b, "  static const double focusRingWidth = %s;\n", fmtFloat(t.Access.FocusRingWidth))
	fmt.Fprintf(&b, "  static const double focusRingOffset = %s;\n", fmtFloat(t.Access.FocusRingOffset))
	fmt.Fprintf(&b, "  static const double minContrastText = %s; // WCAG AA\n", fmtFloat(t.Access.MinContrastText))
	fmt.Fprintf(&b, "  static const double maxTextScale = %s;\n", fmtFloat(t.Access.MaxTextScale))

	b.WriteString("}\n")
	return b.Bytes(), nil
}

func dartShadow(s ShadowToken) string {
	if s == (ShadowToken{}) {
		return "const []"
	}
	alpha := int(s.Alpha*255 + 0.5)
	return fmt.Sprintf("[BoxShadow(color: Color(0x%02X000000), offset: Offset(%s, %s), blurRadius: %s, spreadRadius: %s)]",
		alpha, fmtFloat(s.X), fmtFloat(s.Y), fmtFloat(s.Blur), fmtFloat(s.Spread))
}

func dartStringList(fallback string) string {
	parts := strings.Split(fallback, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {

		p = strings.Trim(strings.TrimSpace(p), `'"`)
		if p != "" {
			out = append(out, fmt.Sprintf("%q", p))
		}
	}
	return "[" + strings.Join(out, ", ") + "]"
}

func CompileCSS(t *Tokens) ([]byte, error) {
	var b bytes.Buffer
	b.WriteString("/* GENERATED FILE -- DO NOT EDIT.\n")
	b.WriteString(" * Source: design/tokens.json\n")
	b.WriteString(" * Regenerate: go run ./cmd/designtool compile\n")
	b.WriteString(" *\n")
	b.WriteString(" * Used by the Chrome extension and as a browsable reference for the palette.\n")
	b.WriteString(" * A11y contrast is verified in Go, not here: every pair below clears WCAG AA\n")
	b.WriteString(" * on the canvas, which CSS alone cannot prove.\n */\n\n")
	b.WriteString(":root {\n")
	b.WriteString("  color-scheme: dark;\n\n")

	fmt.Fprintf(&b, "  /* Canvas: charcoal, never pure black. */\n")
	for _, n := range t.Color.Names() {
		v := mustColor(t, n)
		if strings.HasPrefix(n, "_") {
			continue
		}
		val := cssColor(v.Value, v.Alpha)
		if role := singleLine(v.Role); role != "" {
			fmt.Fprintf(&b, "  /* %s */\n", role)
		}
		fmt.Fprintf(&b, "  --%s: %s;\n", kebab(n), val)
	}

	fmt.Fprintf(&b, "\n  /* HoardScore bands. */\n")
	for _, n := range t.BandNames() {
		band := t.HoardBand[n]
		fmt.Fprintf(&b, "  --hoard-%s: %s; /* %s */\n", n, band.Value, band.Range)
	}

	fmt.Fprintf(&b, "\n  /* Categories. Hue is reinforcement; the label carries the meaning. */\n")
	for _, k := range t.CategoryNames() {
		cat := t.Category[k]
		fmt.Fprintf(&b, "  --cat-%s: %s;\n", kebab(k), cat.Value)
		fmt.Fprintf(&b, "  --cat-%s-surface: %s;\n", kebab(k), cat.Surface)
		fmt.Fprintf(&b, "  --cat-%s-tint: %s;\n", kebab(k), cssColor(cat.Tint, cat.TintAlpha))
	}

	fmt.Fprintf(&b, "\n  /* Space: 4pt grid. */\n")
	for _, k := range sortedKeys(t.Space) {
		fmt.Fprintf(&b, "  --space-%s: %s;\n", k, cssPx(t.Space[k]))
	}
	fmt.Fprintf(&b, "\n  /* Radius: 40px and up on primary surfaces. */\n")
	for _, k := range sortedKeys(t.Radius) {
		fmt.Fprintf(&b, "  --radius-%s: %s;\n", k, cssPx(t.Radius[k]))
	}

	fmt.Fprintf(&b, "\n  /* Type. */\n")
	for _, k := range sortedKeys(t.Type.Scale) {
		s := t.Type.Scale[k]
		fmt.Fprintf(&b, "  --type-%s-size: %s;\n", kebab(k), cssPx(s.Size))
		fmt.Fprintf(&b, "  --type-%s-line-height: %s;\n", kebab(k), fmtFloat(s.LineHeight))
		fmt.Fprintf(&b, "  --type-%s-weight: %d;\n", kebab(k), s.Weight)
		fmt.Fprintf(&b, "  --type-%s-tracking: %sem;\n", kebab(k), fmtFloat(s.Tracking*100))
	}

	fmt.Fprintf(&b, "\n  /* Glass. */\n")
	for _, k := range sortedKeys(t.Glass) {
		g := t.Glass[k]
		fmt.Fprintf(&b, "  --glass-%s-blur: %s;\n", k, cssPx(g.Blur))
		fmt.Fprintf(&b, "  --glass-%s-opacity: %s;\n", k, fmtFloat(g.Opacity))
		fmt.Fprintf(&b, "  --glass-%s-border-alpha: %s;\n", k, fmtFloat(g.BorderAlpha))
	}

	fmt.Fprintf(&b, "\n  /* Shadows: gravity. Downward, soft, never hard. */\n")
	for _, k := range sortedKeys(t.Shadow) {
		s := t.Shadow[k]
		fmt.Fprintf(&b, "  --%s: %s %s %s %s %s;\n", kebab(k),
			cssPx(s.X), cssPx(s.Y), cssPx(s.Blur), cssPx(s.Spread),
			cssColor(s.Color, s.Alpha))
	}

	fmt.Fprintf(&b, "\n  /* Motion. Respect prefers-reduced-motion. */\n")
	for _, tier := range []struct {
		name string
		m    MotionTier
	}{{"instant", t.Motion.Instant}, {"settle", t.Motion.Settle}, {"dramatic", t.Motion.Dramatic}} {
		fmt.Fprintf(&b, "  --motion-%s: %dms;\n", tier.name, int(tier.m.Duration))
		fmt.Fprintf(&b, "  --motion-%s-reduced: %dms;\n", tier.name, int(tier.m.Reduced))
	}
	for _, k := range sortedKeys(t.Motion.Easing) {
		e := t.Motion.Easing[k]
		fmt.Fprintf(&b, "  --ease-%s: cubic-bezier(%s, %s, %s, %s);\n",
			kebab(k), fmtFloat(e.Cubic[0]), fmtFloat(e.Cubic[1]), fmtFloat(e.Cubic[2]), fmtFloat(e.Cubic[3]))
	}

	fmt.Fprintf(&b, "\n  /* Texture. */\n")
	fmt.Fprintf(&b, "  --grain-opacity: %s;\n", fmtFloat(t.Grain.Opacity))

	fmt.Fprintf(&b, "\n  /* Accessibility. */\n")
	fmt.Fprintf(&b, "  --min-touch-target: %s;\n", cssPx(t.Access.MinTouchTarget))
	fmt.Fprintf(&b, "  --focus-ring-width: %s;\n", cssPx(t.Access.FocusRingWidth))
	fmt.Fprintf(&b, "  --focus-ring-offset: %s;\n", cssPx(t.Access.FocusRingOffset))
	b.WriteString("}\n\n")

	b.WriteString("@media (prefers-reduced-motion: reduce) {\n")
	b.WriteString("  :root {\n")
	for _, tier := range []string{"instant", "settle", "dramatic"} {
		fmt.Fprintf(&b, "    --motion-%s: var(--motion-%s-reduced);\n", tier, tier)
	}
	b.WriteString("  }\n}\n")

	return b.Bytes(), nil
}

func CompileBlobs(t *Tokens) ([]byte, error) {
	blobs, err := GenerateBlobs(t)
	if err != nil {
		return nil, err
	}
	var b bytes.Buffer
	b.WriteString("<!-- GENERATED FILE -- DO NOT EDIT.\n")
	b.WriteString("     Source: design/tokens.json (blob variants)\n")
	b.WriteString("     Regenerate: go run ./cmd/designtool compile\n")
	b.WriteString("     Every shape is a closed Catmull-Rom loop through jittered points on a\n")
	b.WriteString("     circle. Change the seed, not the artwork.\n -->\n")
	b.WriteString(`<svg xmlns="http://www.w3.org/2000/svg" width="0" height="0" style="position:absolute">` + "\n")
	b.WriteString("  <defs>\n")
	for _, blob := range blobs {
		fmt.Fprintf(&b, "    %s\n", blob.LinearGradient())
	}
	b.WriteString("  </defs>\n")
	for _, blob := range blobs {
		fmt.Fprintf(&b, "  <path id=\"blob-%s\" d=\"%s\" fill=\"url(#%s)\"/>\n",
			blob.ID, blob.SVGPath(), blob.GradientID())
	}
	b.WriteString("</svg>\n")
	return b.Bytes(), nil
}

func sortedKeys[V any](m map[string]V) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}

func kebab(s string) string {
	return strings.ReplaceAll(strings.ToLower(s), "_", "-")
}

func cssPx(v float64) string { return fmt.Sprintf("%spx", fmtFloat(v)) }

func cssColor(hex string, alpha float64) string {
	if alpha >= 1 {
		return hex
	}
	h := strings.TrimPrefix(hex, "#")
	if len(h) != 6 {
		return hex
	}
	return fmt.Sprintf("rgba(%d, %d, %d, %s)",
		parseHexByte(h[0:2]), parseHexByte(h[2:4]), parseHexByte(h[4:6]), fmtFloat(alpha))
}

func parseHexByte(s string) int {
	v, err := ParseHex("#" + s)
	if err != nil {
		return 0
	}
	return int(v.R)
}

func fmtFloat(v float64) string {
	s := strings.TrimRight(strings.TrimRight(fmt.Sprintf("%.4f", v), "0"), ".")
	if s == "" || s == "-" {
		return "0"
	}
	return s
}

func singleLine(s string) string {
	return strings.TrimSpace(strings.ReplaceAll(strings.ReplaceAll(s, "\n", " "), "\r", ""))
}

func mustColor(t *Tokens, name string) ColorValue {
	v, ok := t.Ref(name)
	if !ok {
		return ColorValue{Value: "#000000", Alpha: 1}
	}
	if v.Alpha == 0 {
		v.Alpha = 1
	}
	return v
}
