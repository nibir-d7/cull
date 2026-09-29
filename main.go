package main

import (
	"fmt"
	"math"
)

type R struct{ R, G, B float64 }

func hx(s string) R {
	var v [3]int
	for i := 0; i < 3; i++ {
		fmt.Sscanf(s[i*2:i*2+2], "%02x", &v[i])
	}
	return R{float64(v[0]) / 255, float64(v[1]) / 255, float64(v[2]) / 255}
}
func L(c R) float64 {
	f := func(v float64) float64 {
		if v <= 0.03928 {
			return v / 12.92
		}
		return math.Pow((v+0.055)/1.055, 2.4)
	}
	return 0.2126*f(c.R) + 0.7152*f(c.G) + 0.0722*f(c.B)
}
func CR(a, b R) float64 {
	la, lb := L(a), L(b)
	if lb > la {
		la, lb = lb, la
	}
	return (la + 0.05) / (lb + 0.05)
}

func mix(a, b R, t float64) R { return R{a.R + (b.R-a.R)*t, a.G + (b.G-a.G)*t, a.B + (b.B-a.B)*t} }
func main() {
	cream := hx("FDF0D5")
	ochre := hx("B69467")
	inks := map[string]string{"ink_tertiary": "5A5750", "ink_secondary": "3D3A33", "ink_mono": "4A463D",
		"signal_dim": "18685E", "accent_dim": "6C5B31", "danger_dim": "924633", "focus": "0E2A26", "warn": "6C5B31", "success": "18685E"}
	lightest := ""
	lowest := -1.0
	for k, v := range inks {
		if L(hx(v)) > lowest {
			lowest = L(hx(v))
			lightest = k
		}
	}
	fmt.Printf("lightest ink token: %s (lum %.4f)\n\n", lightest, lowest)

	for t := 0.0; t <= 0.55; t += 0.05 {
		c := mix(cream, ochre, t)
		worst := 99.0
		worstK := ""
		for k, v := range inks {
			if r := CR(hx(v), c); r < worst {
				worst, worstK = r, k
			}
		}
		h := fmt.Sprintf("%02X%02X%02X", int(c.R*255+0.5), int(c.G*255+0.5), int(c.B*255+0.5))
		sep := CR(c, cream)
		ok := "  "
		if sep >= 1.30 && worst >= 4.65 {
			ok = "OK"
		}
		fmt.Printf("t=%.2f  #%s  sep %5.2f  worst ink %5.2f (%s)  %s\n", t, h, sep, worst, worstK, ok)
	}
}
