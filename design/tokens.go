package design

import (
	"embed"
	"encoding/json"
	"fmt"
	"math"
	"os"
	"sort"
	"strconv"
	"strings"
)

//go:embed tokens.json components.json
var files embed.FS

type Tokens struct {
	Meta Meta `json:"meta"`

	Color     ColorRamp              `json:"color"`
	HoardBand map[string]BandToken   `json:"hoardBand"`
	Category  map[string]Category    `json:"category"`
	Type      TypeToken              `json:"type"`
	Space     map[string]float64     `json:"space"`
	Radius    map[string]float64     `json:"radius"`
	Glass     map[string]GlassToken  `json:"glass"`
	Shadow    map[string]ShadowToken `json:"shadow"`
	Motion    MotionToken            `json:"motion"`
	Grain     GrainToken             `json:"grain"`
	Blob      BlobToken              `json:"blob"`
	Layout    LayoutToken            `json:"layout"`
	Access    A11yToken              `json:"accessibility"`

	refs map[string]ColorValue
}

type Meta struct {
	Name        string `json:"name"`
	Version     string `json:"version"`
	Description string `json:"description"`
	Canvas      string `json:"canvas"`
	Reference   string `json:"reference"`
}

type ColorValue struct {
	Value string  `json:"value"`
	Alpha float64 `json:"alpha"`
	Role  string  `json:"role"`
}

type BandToken struct {
	Value   string `json:"value"`
	Graphic string `json:"graphic"`
	Label   string `json:"label"`
	Range   string `json:"range"`
}

type Category struct {
	Label     string  `json:"label"`
	Value     string  `json:"value"`
	Text      string  `json:"text"`
	Surface   string  `json:"surface"`
	Tint      string  `json:"tint"`
	TintAlpha float64 `json:"tintAlpha"`
}

type TypeToken struct {
	Font  map[string]FontToken `json:"font"`
	Scale map[string]TypeStyle `json:"scale"`
}

type FontToken struct {
	Family   string `json:"family"`
	Fallback string `json:"fallback"`
	Note     string `json:"note"`
}

type TypeStyle struct {
	Font       string  `json:"font"`
	Size       float64 `json:"size"`
	LineHeight float64 `json:"lineHeight"`
	Weight     int     `json:"weight"`
	Tracking   float64 `json:"tracking"`
	Use        string  `json:"use"`
}

type GlassToken struct {
	Surface     string  `json:"surface"`
	Blur        float64 `json:"blur"`
	Opacity     float64 `json:"opacity"`
	BorderAlpha float64 `json:"borderAlpha"`
	Shadow      string  `json:"shadow"`
}

type ShadowToken struct {
	X      float64 `json:"x"`
	Y      float64 `json:"y"`
	Blur   float64 `json:"blur"`
	Spread float64 `json:"spread"`
	Color  string  `json:"color"`
	Alpha  float64 `json:"alpha"`
}

type MotionTier struct {
	Duration float64 `json:"duration"`
	Easing   string  `json:"easing"`
	Reduced  float64 `json:"reduced"`
	Use      string  `json:"use"`
}

type MotionToken struct {
	Instant  MotionTier        `json:"instant"`
	Settle   MotionTier        `json:"settle"`
	Dramatic MotionTier        `json:"dramatic"`
	Easing   map[string]Easing `json:"easing"`
	Reduced  map[string]string `json:"reducedMotion"`
}

type Easing struct {
	Cubic []float64 `json:"cubic"`

	Overshoots bool   `json:"overshoots"`
	Use        string `json:"use"`
}

type GrainToken struct {
	Opacity    float64 `json:"opacity"`
	Size       int     `json:"size"`
	Monochrome bool    `json:"monochrome"`
}

type BlobToken struct {
	Variants []BlobVariant `json:"variants"`
}

type BlobVariant struct {
	ID           string   `json:"id"`
	Seed         int      `json:"seed"`
	Points       int      `json:"points"`
	Irregularity float64  `json:"irregularity"`
	Colors       []string `json:"colors"`
}

type LayoutToken struct {
	CardMinWidth      float64 `json:"cardMinWidth"`
	CardMaxWidth      float64 `json:"cardMaxWidth"`
	Gutter            float64 `json:"gutter"`
	GridColumns       int     `json:"gridColumns"`
	GrainIrregularity float64 `json:"grainIrregularity"`
	PullQuoteMaxWidth float64 `json:"pullQuoteMaxWidth"`
	RoastCardAspect   string  `json:"roastCardAspect"`
}

type A11yToken struct {
	MinContrastText      float64 `json:"minContrastText"`
	MinContrastLargeText float64 `json:"minContrastLargeText"`
	MinContrastNonText   float64 `json:"minContrastNonText"`
	MinTouchTarget       float64 `json:"minTouchTarget"`
	MaxTextScale         float64 `json:"maxTextScale"`
	FocusRingWidth       float64 `json:"focusRingWidth"`
	FocusRingOffset      float64 `json:"focusRingOffset"`
	ReducedMotion        bool    `json:"reducedMotion"`
}

type ColorRamp struct {
	values map[string]ColorValue
}

func (c *ColorRamp) UnmarshalJSON(b []byte) error {
	var raw map[string]json.RawMessage
	if err := json.Unmarshal(b, &raw); err != nil {
		return err
	}
	c.values = make(map[string]ColorValue, len(raw))
	for k, v := range raw {
		if strings.HasPrefix(k, "_") {
			continue
		}
		var cv ColorValue
		if err := json.Unmarshal(v, &cv); err != nil {
			return fmt.Errorf("design: colour token %q: %w", k, err)
		}
		c.values[k] = cv
	}
	return nil
}

func (c ColorRamp) Get(name string) (ColorValue, bool) {
	v, ok := c.values[name]
	return v, ok
}

func (c ColorRamp) Names() []string {
	out := make([]string, 0, len(c.values))
	for k := range c.values {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}

func (c ColorRamp) All() map[string]ColorValue { return c.values }

func (c ColorRamp) Has(name string) bool { _, ok := c.values[name]; return ok }

func Load() (*Tokens, error) {
	b, err := files.ReadFile("tokens.json")
	if err != nil {
		return nil, err
	}
	return parse(b)
}

func LoadFromFile(path string) (*Tokens, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	return parse(b)
}

func parse(b []byte) (*Tokens, error) {

	stripped, err := stripNotes(b)
	if err != nil {
		return nil, err
	}

	var t Tokens
	if err := json.Unmarshal(stripped, &t); err != nil {
		return nil, fmt.Errorf("design: parse tokens: %w", err)
	}
	t.refs = t.Color.All()

	for k, v := range t.refs {
		if v.Alpha == 0 {
			v.Alpha = 1
			t.refs[k] = v
		}
	}
	if err := t.validate(); err != nil {
		return nil, err
	}
	return &t, nil
}

func stripNotes(b []byte) ([]byte, error) {
	var tree any
	if err := json.Unmarshal(b, &tree); err != nil {
		return nil, fmt.Errorf("design: parse tokens: %w", err)
	}
	return json.Marshal(pruneNotes(tree))
}

func pruneNotes(v any) any {
	switch t := v.(type) {
	case map[string]any:
		out := make(map[string]any, len(t))
		for k, child := range t {
			if strings.HasPrefix(k, "_") {
				continue
			}
			out[k] = pruneNotes(child)
		}
		return out
	case []any:
		for i := range t {
			t[i] = pruneNotes(t[i])
		}
		return t
	default:
		return v
	}
}

func (t *Tokens) validate() error {
	var problems []string

	required := []string{
		"canvas", "canvas_deep", "ink_primary", "ink_secondary", "ink_tertiary",
		"ink_mono", "signal", "danger", "focus", "surface_1", "surface_4",
	}
	for _, name := range required {
		if _, ok := t.refs[name]; !ok {
			problems = append(problems, "missing required colour token: "+name)
		}
	}

	for name, v := range t.refs {
		if strings.HasPrefix(name, "_") {
			continue
		}
		if _, err := ParseHex(v.Value); err != nil {
			problems = append(problems, fmt.Sprintf("colour %s: %v", name, err))
		}
		if v.Alpha < 0 || v.Alpha > 1 {
			problems = append(problems, fmt.Sprintf("colour %s: alpha %v out of range", name, v.Alpha))
		}
	}

	if len(t.Category) != 8 {
		problems = append(problems, fmt.Sprintf("expected 8 categories, got %d", len(t.Category)))
	}
	for key, c := range t.Category {
		if _, err := ParseHex(c.Value); err != nil {
			problems = append(problems, fmt.Sprintf("category %s value: %v", key, err))
		}
		if _, err := ParseHex(c.Surface); err != nil {
			problems = append(problems, fmt.Sprintf("category %s surface: %v", key, err))
		}
		if c.TintAlpha <= 0 || c.TintAlpha > 1 {
			problems = append(problems, fmt.Sprintf("category %s: tintAlpha %v out of range", key, c.TintAlpha))
		}
	}

	for name, g := range t.Glass {
		if _, ok := t.refs[g.Surface]; !ok {
			problems = append(problems, fmt.Sprintf("glass %s references unknown surface %q", name, g.Surface))
		}
		if _, ok := t.Shadow[g.Shadow]; !ok {
			problems = append(problems, fmt.Sprintf("glass %s references unknown shadow %q", name, g.Shadow))
		}
		if g.Blur < 0 {
			problems = append(problems, fmt.Sprintf("glass %s: negative blur", name))
		}
	}

	for name, s := range t.Shadow {
		if s.Blur < 0 {
			problems = append(problems, fmt.Sprintf("shadow %s: negative blur", name))
		}
		if s.Y < 0 {
			problems = append(problems, fmt.Sprintf("shadow %s: y offset must not be negative; light falls from above", name))
		}
		if s.Alpha < 0 || s.Alpha > 1 {
			problems = append(problems, fmt.Sprintf("shadow %s: alpha %v out of range", name, s.Alpha))
		}
	}

	for name, s := range t.Type.Scale {
		if _, ok := t.Type.Font[s.Font]; !ok {
			problems = append(problems, fmt.Sprintf("type %s references unknown font %q", name, s.Font))
		}
		if s.Size <= 0 {
			problems = append(problems, fmt.Sprintf("type %s: size must be positive", name))
		}
		if s.LineHeight <= 0 {
			problems = append(problems, fmt.Sprintf("type %s: lineHeight must be positive", name))
		}
	}
	if len(t.Type.Font) == 0 {
		problems = append(problems, "no fonts defined")
	}

	for _, tier := range []struct {
		name string
		m    MotionTier
	}{{"instant", t.Motion.Instant}, {"settle", t.Motion.Settle}, {"dramatic", t.Motion.Dramatic}} {
		d := tier.m.Duration
		if d <= 0 || d > 600 {

			problems = append(problems, fmt.Sprintf("motion tier %s: duration %vms outside 0-600", tier.name, d))
		}
		if tier.m.Easing == "" {
			problems = append(problems, "motion tier "+tier.name+" has no easing")
		} else if _, known := t.Motion.Easing[tier.m.Easing]; !known {
			problems = append(problems, fmt.Sprintf("motion %s references unknown easing %q", tier.name, tier.m.Easing))
		}

		if tier.m.Reduced < 0 || tier.m.Reduced > d {
			problems = append(problems, fmt.Sprintf("motion tier %s: reduced duration %v must be between 0 and the real duration", tier.name, tier.m.Reduced))
		}
	}
	for name, e := range t.Motion.Easing {
		if len(e.Cubic) != 4 {
			problems = append(problems, fmt.Sprintf("easing %s needs exactly 4 control points, got %d", name, len(e.Cubic)))
			continue
		}

		if e.Cubic[0] < 0 || e.Cubic[0] > 1 {
			problems = append(problems, fmt.Sprintf("easing %s: x1 = %v outside 0-1", name, e.Cubic[0]))
		}
		if e.Cubic[2] < 0 || e.Cubic[2] > 1 {
			problems = append(problems, fmt.Sprintf("easing %s: x2 = %v outside 0-1", name, e.Cubic[2]))
		}
		for _, i := range []int{1, 3} {
			v := e.Cubic[i]
			if math.IsNaN(v) || math.IsInf(v, 0) {
				problems = append(problems, fmt.Sprintf("easing %s: y control point %d is not finite", name, i))
				continue
			}

			if v < -1 || v > 2 {
				problems = append(problems, fmt.Sprintf("easing %s: y control point %d = %v is outside -1..2; a small overshoot is intentional, a wild swing is a typo", name, i, v))
			}
		}
	}

	overshoots := 0
	for _, e := range t.Motion.Easing {
		if e.Overshoots {
			overshoots++
		}
	}
	if overshoots > 1 {
		problems = append(problems, fmt.Sprintf("%d easing curves overshoot; at most one is allowed", overshoots))
	}

	for _, v := range t.Blob.Variants {
		if v.Points < 4 {
			problems = append(problems, fmt.Sprintf("blob %s: needs at least 4 points to form a loop", v.ID))
		}
		if v.Irregularity < 0 || v.Irregularity > 1 {
			problems = append(problems, fmt.Sprintf("blob %s: irregularity %v outside 0-1", v.ID, v.Irregularity))
		}
		if len(v.Colors) != 2 {
			problems = append(problems, fmt.Sprintf("blob %s: needs exactly 2 gradient colours, got %d", v.ID, len(v.Colors)))
		}
		for _, cn := range v.Colors {
			if _, ok := t.refs[cn]; !ok {
				problems = append(problems, fmt.Sprintf("blob %s references unknown colour %q", v.ID, cn))
			}
		}
	}

	if t.Grain.Size < 8 {
		problems = append(problems, "grain tile size must be at least 8px")
	}
	if t.Grain.Opacity <= 0 || t.Grain.Opacity > 0.15 {

		problems = append(problems, fmt.Sprintf("grain opacity %v outside 0-0.15", t.Grain.Opacity))
	}
	if t.Access.MinContrastText < 4.5 {
		problems = append(problems, "accessibility.minContrastText must be at least 4.5 (WCAG AA)")
	}
	if t.Access.MinTouchTarget < 44 {
		problems = append(problems, fmt.Sprintf("minTouchTarget %v is below the 44pt minimum", t.Access.MinTouchTarget))
	}
	if !t.Access.ReducedMotion {
		problems = append(problems, "accessibility.reducedMotion must be true")
	}

	if len(problems) > 0 {
		sort.Strings(problems)
		return fmt.Errorf("design: %d token problem(s):\n  - %s",
			len(problems), strings.Join(problems, "\n  - "))
	}
	return nil
}

func (t *Tokens) Ref(name string) (ColorValue, bool) {
	v, ok := t.refs[name]
	return v, ok
}

type RGB struct{ R, G, B uint8 }

func (c RGB) Hex() string { return fmt.Sprintf("#%02X%02X%02X", c.R, c.G, c.B) }

func ParseHex(s string) (RGB, error) {
	h := strings.TrimSpace(s)
	if !strings.HasPrefix(h, "#") {
		return RGB{}, fmt.Errorf("invalid colour %q: must start with #", s)
	}
	h = h[1:]

	expand := func(b string) (uint8, error) {
		v, err := strconv.ParseUint(b, 16, 8)
		if err != nil {
			return 0, fmt.Errorf("invalid colour %q: %q is not hex", s, b)
		}
		return uint8(v), nil
	}

	switch len(h) {
	case 3:
		r, err := expand(h[0:1] + h[0:1])
		if err != nil {
			return RGB{}, err
		}
		g, err := expand(h[1:2] + h[1:2])
		if err != nil {
			return RGB{}, err
		}
		b, err := expand(h[2:3] + h[2:3])
		if err != nil {
			return RGB{}, err
		}
		return RGB{R: r, G: g, B: b}, nil
	case 6, 8:
		r, err := expand(h[0:2])
		if err != nil {
			return RGB{}, err
		}
		g, err := expand(h[2:4])
		if err != nil {
			return RGB{}, err
		}
		b, err := expand(h[4:6])
		if err != nil {
			return RGB{}, err
		}
		return RGB{R: r, G: g, B: b}, nil
	default:
		return RGB{}, fmt.Errorf("invalid colour %q: expected #RGB, #RRGGBB or #RRGGBBAA", s)
	}
}

func MustHex(s string) RGB {
	c, err := ParseHex(s)
	if err != nil {
		return RGB{}
	}
	return c
}

func (c RGB) RelativeLuminance() float64 {
	return 0.2126*linearize(c.R) + 0.7152*linearize(c.G) + 0.0722*linearize(c.B)
}

func linearize(v uint8) float64 {
	s := float64(v) / 255
	if s <= 0.03928 {
		return s / 12.92
	}
	return math.Pow((s+0.055)/1.055, 2.4)
}

func ContrastRatio(a, b RGB) float64 {
	la, lb := a.RelativeLuminance(), b.RelativeLuminance()
	if la < lb {
		la, lb = lb, la
	}
	return (la + 0.05) / (lb + 0.05)
}

func Over(fg RGB, alpha float64, bg RGB) RGB {
	mix := func(f, b uint8) uint8 {
		return uint8(math.Round(float64(f)*alpha + float64(b)*(1-alpha)))
	}
	return RGB{R: mix(fg.R, bg.R), G: mix(fg.G, bg.G), B: mix(fg.B, bg.B)}
}

func (t *Tokens) CategoryNames() []string {
	out := make([]string, 0, len(t.Category))
	for k := range t.Category {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}

func (t *Tokens) BandNames() []string {
	order := []string{"fresh", "stale", "rotting", "graveyard"}
	out := make([]string, 0, len(order))
	for _, n := range order {
		if _, ok := t.HoardBand[n]; ok {
			out = append(out, n)
		}
	}
	return out
}
