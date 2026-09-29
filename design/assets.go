package design

import (
	"fmt"
	"image"
	"image/color"
	"image/png"
	"math"
	"math/rand/v2"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

func GenerateGrain(t *Tokens, path string) error {
	size := t.Grain.Size
	if size < 8 {
		return fmt.Errorf("design: grain size %d too small", size)
	}

	img := image.NewNRGBA(image.Rect(0, 0, size, size))

	rng := rand.New(rand.NewPCG(uint64(size), 0xB1E5))
	noise := make([]float64, size*size)
	for i := range noise {
		noise[i] = rng.Float64()
	}
	smoothed := smoothTorus(noise, size, 2)

	v := clamp01((smoothed[0] + smoothed[size/2*size+size/2] + smoothed[size-1]) / 3)

	for y := 0; y < size; y++ {
		for x := 0; x < size; x++ {

			g := uint8(math.Round(128 + (smoothed[y*size+x]-v)*92))
			if t.Grain.Monochrome {
				img.SetNRGBA(x, y, color.NRGBA{R: g, G: g, B: g, A: 255})
				continue
			}
			img.SetNRGBA(x, y, color.NRGBA{R: g, G: g, B: g, A: 255})
		}
	}

	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	f, err := os.Create(path)
	if err != nil {
		return err
	}
	defer f.Close()
	enc := png.Encoder{CompressionLevel: png.BestCompression}
	if err := enc.Encode(f, img); err != nil {
		return err
	}
	return nil
}

func smoothTorus(in []float64, size, passes int) []float64 {
	out := make([]float64, len(in))
	copy(out, in)
	tmp := make([]float64, len(in))

	for p := 0; p < passes; p++ {
		for y := 0; y < size; y++ {
			for x := 0; x < size; x++ {
				sum := 0.0
				for dy := -1; dy <= 1; dy++ {
					for dx := -1; dx <= 1; dx++ {
						sy := ((y+dy)%size + size) % size
						sx := ((x+dx)%size + size) % size
						sum += out[sy*size+sx]
					}
				}
				tmp[y*size+x] = sum / 9
			}
		}
		copy(out, tmp)
	}
	return out
}

func clamp01(v float64) float64 { return math.Min(math.Max(v, 0), 1) }

type BlobPoint struct {
	X, Y float64
}

type Blob struct {
	ID           string
	Points       []BlobPoint
	Irregularity float64
	Colors       [2]RGB
}

func GenerateBlob(v BlobVariant, palette map[string]RGB) (Blob, error) {
	if v.Points < 4 {
		return Blob{}, fmt.Errorf("design: blob %s needs at least 4 points", v.ID)
	}

	rng := rand.New(rand.NewPCG(uint64(v.Seed), uint64(v.Seed)*0x9E3779B1))

	pts := make([]BlobPoint, v.Points)

	angleJitter := rng.Float64() * math.Pi * 2
	for i := 0; i < v.Points; i++ {
		base := (float64(i)/float64(v.Points))*math.Pi*2 + angleJitter
		r := 0.5 * (1 - v.Irregularity*0.35 + rng.Float64()*v.Irregularity*0.7)
		pts[i] = BlobPoint{
			X: 0.5 + math.Cos(base)*r,
			Y: 0.5 + math.Sin(base)*r,
		}
	}

	blob := Blob{ID: v.ID, Points: pts, Irregularity: v.Irregularity}
	for i, name := range v.Colors {
		c, ok := palette[name]
		if !ok {
			return Blob{}, fmt.Errorf("design: blob %s references unknown colour %q", v.ID, name)
		}
		blob.Colors[i] = c
	}
	normalizeBlob(&blob)
	return blob, nil
}

func normalizeBlob(b *Blob) {
	n := len(b.Points)
	if n < 3 {
		return
	}

	minX, minY := math.Inf(1), math.Inf(1)
	maxX, maxY := math.Inf(-1), math.Inf(-1)
	include := func(x, y float64) {
		minX = math.Min(minX, x)
		minY = math.Min(minY, y)
		maxX = math.Max(maxX, x)
		maxY = math.Max(maxY, y)
	}

	for i := 0; i < n; i++ {
		p0 := b.Points[(i-1+n)%n]
		p1 := b.Points[i]
		p2 := b.Points[(i+1)%n]
		p3 := b.Points[(i+2)%n]
		include(p1.X, p1.Y)
		include(p1.X+(p2.X-p0.X)/6, p1.Y+(p2.Y-p0.Y)/6)
		include(p2.X-(p3.X-p1.X)/6, p2.Y-(p3.Y-p1.Y)/6)
	}

	w, h := maxX-minX, maxY-minY
	if w <= 0 || h <= 0 {
		return
	}

	scale := 1 / math.Max(w, h)
	cx, cy := (minX+maxX)/2, (minY+maxY)/2

	for i := range b.Points {
		b.Points[i].X = clampUnit((b.Points[i].X-cx)*scale + 0.5)
		b.Points[i].Y = clampUnit((b.Points[i].Y-cy)*scale + 0.5)
	}
}

func clampUnit(v float64) float64 {
	if v < 0 || v > 1 {
		return math.Round(clamp01(v)*1e6) / 1e6
	}
	return math.Round(v*1e6) / 1e6
}

func GenerateBlobs(t *Tokens) ([]Blob, error) {
	palette := make(map[string]RGB, len(t.Color.All()))
	for name, v := range t.Color.All() {
		rgb, err := ParseHex(v.Value)
		if err != nil {
			return nil, err
		}
		palette[name] = rgb
	}
	out := make([]Blob, 0, len(t.Blob.Variants))
	for _, v := range t.Blob.Variants {
		b, err := GenerateBlob(v, palette)
		if err != nil {
			return nil, err
		}
		out = append(out, b)
	}
	return out, nil
}

func (b Blob) SVGPath() string {
	n := len(b.Points)
	if n < 3 {
		return ""
	}
	var sb strings.Builder
	sb.WriteString("M ")
	fmt.Fprintf(&sb, "%.4f %.4f", clampUnit(b.Points[0].X), clampUnit(b.Points[0].Y))

	for i := 0; i < n; i++ {
		p0 := b.Points[(i-1+n)%n]
		p1 := b.Points[i]
		p2 := b.Points[(i+1)%n]
		p3 := b.Points[(i+2)%n]

		c1x := p1.X + (p2.X-p0.X)/6
		c1y := p1.Y + (p2.Y-p0.Y)/6
		c2x := p2.X - (p3.X-p1.X)/6
		c2y := p2.Y - (p3.Y-p1.Y)/6

		fmt.Fprintf(&sb, " C %.4f %.4f, %.4f %.4f, %.4f %.4f",
			clampUnit(c1x), clampUnit(c1y), clampUnit(c2x), clampUnit(c2y),
			clampUnit(p2.X), clampUnit(p2.Y))
	}
	sb.WriteString(" Z")
	return sb.String()
}

func (b Blob) GradientID() string { return "blob-gradient-" + b.ID }

func (b Blob) LinearGradient() string {
	return fmt.Sprintf(
		`<linearGradient id="%s" x1="0" y1="0" x2="1" y2="1">`+
			`<stop offset="0%%" stop-color="%s"/>`+
			`<stop offset="100%%" stop-color="%s"/>`+
			`</linearGradient>`,
		b.GradientID(), b.Colors[0].Hex(), b.Colors[1].Hex())
}

func (b Blob) BoundingBox() (minX, minY, maxX, maxY float64) {
	minX, minY = 1, 1
	maxX, maxY = 0, 0
	for _, p := range b.Points {
		minX = math.Min(minX, p.X)
		minY = math.Min(minY, p.Y)
		maxX = math.Max(maxX, p.X)
		maxY = math.Max(maxY, p.Y)
	}
	return
}

func (t *Tokens) PaletteHex() map[string]string {
	out := make(map[string]string, len(t.Color.All()))
	for k, v := range t.Color.All() {
		out[k] = v.Value
	}
	return out
}

func CategoryNamesSorted(t *Tokens) []string {
	out := t.CategoryNames()
	sort.Strings(out)
	return out
}
