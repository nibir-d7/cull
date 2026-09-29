package main

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/cull-app/cull/design"
)

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(2)
	}

	var err error
	switch os.Args[1] {
	case "verify":
		err = cmdVerify()
	case "contrast":
		err = cmdContrast()
	case "inventory":
		err = cmdInventory()
	case "compile":
		err = cmdCompile()
	case "assets":
		err = cmdAssets()
	case "palette":
		err = cmdPalette()
	case "-h", "--help", "help":
		usage()
		return
	default:
		fmt.Fprintf(os.Stderr, "unknown command %q\n\n", os.Args[1])
		usage()
		os.Exit(2)
	}

	if err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}

func usage() {
	fmt.Fprint(os.Stderr, `designtool -- CULL design tokens

  designtool verify     validate tokens and the component inventory
  designtool contrast   print the contrast matrix against every surface
  designtool inventory  print every component and the states it must implement
  designtool palette    print the palette with contrast ratios
  designtool compile    emit tokens.g.dart, tokens.css and blobs.svg
  designtool assets     emit the grain tile and blob assets

`)
}

func load() (*design.Tokens, error) { return design.Load() }

func cmdVerify() error {
	tk, err := load()
	if err != nil {
		return err
	}
	inv, err := design.LoadInventory()
	if err != nil {
		return err
	}

	fmt.Printf("%s design tokens %s -- valid\n\n", tk.Meta.Name, tk.Meta.Version)
	fmt.Printf("  colour tokens      %d\n", len(tk.Color.Names()))
	fmt.Printf("  categories         %d\n", len(tk.Category))
	fmt.Printf("  hoard bands        %d\n", len(tk.BandNames()))
	fmt.Printf("  type styles        %d\n", len(tk.Type.Scale))
	fmt.Printf("  fonts              %d\n", len(tk.Type.Font))
	fmt.Printf("  glass levels       %d\n", len(tk.Glass))
	fmt.Printf("  shadows            %d\n", len(tk.Shadow))
	fmt.Printf("  easing curves      %d\n", len(tk.Motion.Easing))
	fmt.Printf("  blob variants      %d\n", len(tk.Blob.Variants))
	fmt.Printf("  components         %d\n", len(inv.Components))
	fmt.Printf("  screens            %d\n", len(inv.Screens))
	fmt.Printf("  a11y checks        %d\n", len(inv.Accessibility))
	return nil
}

func cmdContrast() error {
	tk, err := load()
	if err != nil {
		return err
	}
	min := tk.Access.MinContrastText

	surfaces := []string{"canvas", "canvas_deep", "canvas_lift", "surface_1", "surface_2", "surface_3", "surface_4"}
	texts := []string{"ink_primary", "ink_secondary", "ink_tertiary", "ink_mono", "signal", "danger", "success", "warn", "focus"}

	fmt.Println("TEXT ON SURFACE                       (AA needs 4.5:1)")
	fmt.Printf("  %-14s", "")
	for _, s := range surfaces {
		fmt.Printf("%12s", short(s))
	}
	fmt.Println()
	failures := 0
	for _, text := range texts {
		tv, _ := tk.Ref(text)
		tc := design.MustHex(tv.Value)
		fmt.Printf("  %-14s", short(text))
		for _, s := range surfaces {
			sv, _ := tk.Ref(s)
			ratio := design.ContrastRatio(tc, design.MustHex(sv.Value))
			mark := " "
			if ratio < min {
				mark = "!"
				failures++
			}
			fmt.Printf("%11.2f%s", ratio, mark)
		}
		fmt.Println()
	}

	fmt.Println("\nCATEGORY HUE ON ITS OWN SURFACE        (AA needs 4.5:1)")
	for _, k := range tk.CategoryNames() {
		c := tk.Category[k]
		ratio := design.ContrastRatio(design.MustHex(c.Value), design.MustHex(c.Surface))
		mark := " "
		if ratio < min {
			mark = "!"
			failures++
		}
		fmt.Printf("  %-20s %7.2f%s  hue %s on %s\n", k, ratio, mark, c.Value, c.Surface)
	}

	fmt.Println("\nCATEGORY HUE ON CANVAS                 (non-text needs 3.0:1)")
	canvas, _ := tk.Ref("canvas")
	for _, k := range tk.CategoryNames() {
		ratio := design.ContrastRatio(design.MustHex(tk.Category[k].Value), design.MustHex(canvas.Value))
		mark := " "
		if ratio < tk.Access.MinContrastNonText {
			mark = "!"
			failures++
		}
		fmt.Printf("  %-20s %7.2f%s\n", k, ratio, mark)
	}

	fmt.Println("\nHOARD BANDS ON CANVAS")
	for _, b := range tk.BandNames() {
		ratio := design.ContrastRatio(design.MustHex(tk.HoardBand[b].Value), design.MustHex(canvas.Value))
		fmt.Printf("  %-20s %7.2f   %s\n", b, ratio, tk.HoardBand[b].Range)
	}

	if failures > 0 {
		return fmt.Errorf("%d pair(s) below the required ratio", failures)
	}
	fmt.Println("\nall pairs pass")
	return nil
}

func cmdPalette() error {
	tk, err := load()
	if err != nil {
		return err
	}
	canvas, _ := tk.Ref("canvas")

	fmt.Println("CATEGORY PALETTE  (hue on canvas, greyscale luminance)")
	rows := make([]string, 0, len(tk.Category))
	for _, k := range tk.CategoryNames() {
		c := tk.Category[k]
		rgb := design.MustHex(c.Value)
		rows = append(rows, fmt.Sprintf("  %-20s %s  %s  contrast %5.2f  lum %.3f",
			k, c.Value, swatch(rgb), design.ContrastRatio(rgb, design.MustHex(canvas.Value)), rgb.RelativeLuminance()))
	}
	sort.Strings(rows)
	for _, r := range rows {
		fmt.Println(r)
	}

	fmt.Println("\\nGUILT RAMP")
	for _, b := range tk.BandNames() {
		rgb := design.MustHex(tk.HoardBand[b].Value)
		fmt.Printf("  %-20s %s  %s  %s\n", b, tk.HoardBand[b].Value, swatch(rgb), tk.HoardBand[b].Range)
	}
	return nil
}

func cmdInventory() error {
	inv, err := design.LoadInventory()
	if err != nil {
		return err
	}
	fmt.Println("COMPONENTS")
	for _, id := range inv.ComponentIDs() {
		c, _ := inv.Component(id)
		flags := []string{}
		if c.Async {
			flags = append(flags, "async")
		}
		if c.Destructive {
			flags = append(flags, "destructive")
		}
		if c.Interactive {
			flags = append(flags, "interactive")
		}
		flagStr := ""
		if len(flags) > 0 {
			flagStr = " [" + strings.Join(flags, ", ") + "]"
		}
		fmt.Printf("\n  %s%s\n", c.ID, flagStr)
		fmt.Printf("    %s\n", c.Role)
		fmt.Printf("    states: %s\n", strings.Join(c.States, ", "))
		if c.Notes != "" {
			fmt.Printf("    note:   %s\n", c.Notes)
		}
	}

	fmt.Println("\n\nSCREENS")
	for _, id := range inv.ScreenIDs() {
		s, _ := inv.Screen(id)
		fmt.Printf("\n  %s\n", s.ID)
		fmt.Printf("    states: %s\n", strings.Join(s.States, ", "))
		if s.RequiredCopy != "" {
			fmt.Printf("    copy:   %s\n", s.RequiredCopy)
		}
	}
	return nil
}

func cmdCompile() error {
	tk, err := load()
	if err != nil {
		return err
	}

	artifacts := []struct {
		name string
		path string
		gen  func() ([]byte, error)
	}{
		{"tokens.g.dart", filepath.Join("app_flutter", "lib", "design", "tokens.g.dart"), func() ([]byte, error) {
			return design.CompileDart(tk)
		}},
		{"tokens.css", filepath.Join("design", "generated", "tokens.css"), func() ([]byte, error) {
			return design.CompileCSS(tk)
		}},
		{"blobs.svg", filepath.Join("design", "generated", "blobs.svg"), func() ([]byte, error) {
			return design.CompileBlobs(tk)
		}},
	}

	for _, a := range artifacts {
		body, err := a.gen()
		if err != nil {
			return fmt.Errorf("%s: %w", a.name, err)
		}
		if err := os.MkdirAll(filepath.Dir(a.path), 0o755); err != nil {
			return err
		}
		if err := os.WriteFile(a.path, body, 0o644); err != nil {
			return err
		}
		fmt.Printf("  %-16s %6d bytes  %s\n", a.name, len(body), a.path)
	}
	return nil
}

func cmdAssets() error {
	tk, err := load()
	if err != nil {
		return err
	}

	grainPath := filepath.Join("design", "generated", "grain.png")
	if err := design.GenerateGrain(tk, grainPath); err != nil {
		return err
	}
	if st, err := os.Stat(grainPath); err == nil {
		fmt.Printf("  %-16s %6d bytes  %s (%dx%d)\n", "grain.png", st.Size(), grainPath, tk.Grain.Size, tk.Grain.Size)
	}

	flutterGrain := filepath.Join("app_flutter", "assets", "grain.png")
	if err := design.GenerateGrain(tk, flutterGrain); err != nil {
		return err
	}
	if st, err := os.Stat(flutterGrain); err == nil {
		fmt.Printf("  %-16s %6d bytes  %s\n", "grain.png", st.Size(), flutterGrain)
	}

	blobs, err := design.GenerateBlobs(tk)
	if err != nil {
		return err
	}
	for _, b := range blobs {
		minX, minY, maxX, maxY := b.BoundingBox()
		fmt.Printf("  blob %-4s %2d points  extent %.2f,%.2f -> %.2f,%.2f  %s -> %s\n",
			b.ID, len(b.Points), minX, minY, maxX, maxY, b.Colors[0].Hex(), b.Colors[1].Hex())
	}
	return nil
}

func short(name string) string {
	if len(name) > 10 {
		return name[:10]
	}
	return name
}

func swatch(c design.RGB) string {
	return fmt.Sprintf("\x1b[48;2;%d;%d;%dm  \x1b[0m", c.R, c.G, c.B)
}
