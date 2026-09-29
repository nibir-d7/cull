package ingest

import (
	"strings"
	"unicode/utf8"

	"golang.org/x/net/html"
)

const (
	MethodReadability = "readability"
	MethodOpenGraph   = "opengraph"
	MethodTitle       = "title"
	MethodURL         = "url"
)

const MinReadableChars = 200

func Extract(rawURL string, body []byte) Document {
	doc := Document{
		URL:     rawURL,
		Domain:  DomainOf(rawURL),
		Method:  MethodURL,
		Title:   titleFromURL(rawURL),
		Excerpt: titleFromURL(rawURL),
	}
	if len(body) == 0 {
		return doc
	}

	node, err := html.Parse(strings.NewReader(string(body)))
	if err != nil {

		if t := scrapeTitleWithRegex(string(body)); t != "" {
			doc.Title, doc.Excerpt, doc.Method = t, t, MethodTitle
		}
		return doc
	}

	meta := collectMeta(node)
	if fav := faviconFrom(meta, rawURL); fav != "" {
		doc.FaviconURL = fav
	}

	title := firstNonEmpty(meta["og:title"], meta["twitter:title"], meta["title"], doc.Title)
	doc.Title = cleanTitle(title, doc.Domain)

	if text := readability(node); utf8.RuneCountInString(text) >= MinReadableChars {
		doc.Readable = text
		doc.Excerpt = excerptFrom(text)
		doc.Method = MethodReadability

		if d := cleanText(meta["og:description"]); utf8.RuneCountInString(d) > 20 {
			doc.Excerpt = d
		}
		return doc
	}

	if d := firstNonEmpty(meta["og:description"], meta["twitter:description"], meta["description"]); d != "" {
		doc.Readable = d
		doc.Excerpt = d
		doc.Method = MethodOpenGraph
		return doc
	}

	doc.Readable = doc.Title
	doc.Excerpt = doc.Title
	if doc.Method == MethodURL {
		doc.Method = MethodTitle
	}
	return doc
}

func collectMeta(root *html.Node) map[string]string {
	out := map[string]string{}
	var walk func(*html.Node)
	walk = func(n *html.Node) {
		if n.Type == html.ElementNode && n.Data == "meta" {
			key := attr(n, "property")
			if key == "" {
				key = attr(n, "name")
			}
			content := attr(n, "content")
			if key != "" && content != "" {

				if _, exists := out[strings.ToLower(key)]; !exists {
					out[strings.ToLower(key)] = content
				}
			}
		}
		if n.Type == html.ElementNode && n.Data == "title" {
			if out["title"] == "" {
				out["title"] = textContent(n)
			}
		}
		for c := n.FirstChild; c != nil; c = c.NextSibling {
			walk(c)
		}
	}
	walk(root)
	return out
}

func attr(n *html.Node, name string) string {
	for _, a := range n.Attr {
		if strings.EqualFold(a.Key, name) {
			return a.Val
		}
	}
	return ""
}

func faviconFrom(meta map[string]string, rawURL string) string {

	if i := meta["og:image"]; i != "" {
		if abs := absoluteURL(rawURL, i); abs != "" {
			return abs
		}
	}
	domain := DomainOf(rawURL)
	if domain == "" {
		return ""
	}
	return "https://" + domain + "/favicon.ico"
}

func absoluteURL(base, href string) string {
	if href == "" {
		return ""
	}
	if strings.HasPrefix(href, "http://") || strings.HasPrefix(href, "https://") {
		return href
	}
	b, err := parseURL(base)
	if err != nil {
		return ""
	}
	ref, err := parseURL(href)
	if err != nil {
		return ""
	}
	return b.ResolveReference(ref).String()
}

var noisyTags = map[string]bool{
	"script": true, "style": true, "noscript": true, "iframe": true,
	"nav": true, "header": true, "footer": true, "aside": true,
	"form": true, "button": true, "svg": true, "canvas": true,
	"video": true, "audio": true, "select": true, "template": true,
	"figcaption": false,
}

var blockTags = map[string]bool{
	"article": true, "main": true, "section": true, "div": true,
	"p": true, "pre": true, "blockquote": true, "li": true, "td": true,
}

const minBlockChars = 40

func readability(root *html.Node) string {
	stripNoise(root)

	var best *html.Node
	bestScore := 0.0

	var walk func(*html.Node)
	walk = func(n *html.Node) {
		if n.Type == html.ElementNode && blockTags[n.Data] {
			if score := scoreBlock(n); score > bestScore {
				bestScore = score
				best = n
			}
		}
		for c := n.FirstChild; c != nil; c = c.NextSibling {
			walk(c)
		}
	}
	walk(root)

	if best == nil {
		return normalizeWhitespace(textContent(root))
	}

	for p := best.Parent; p != nil; p = p.Parent {
		if p.Type == html.ElementNode && (p.Data == "article" || p.Data == "main") {
			best = p
			break
		}
	}

	parts := collectBlocks(best)
	return normalizeWhitespace(strings.Join(parts, "\n\n"))
}

func scoreBlock(n *html.Node) float64 {
	text := textContent(n)
	length := utf8.RuneCountInString(text)
	if length < minBlockChars {
		return 0
	}

	linkChars := 0
	var countLinks func(*html.Node)
	countLinks = func(x *html.Node) {
		if x.Type == html.ElementNode && x.Data == "a" {
			linkChars += utf8.RuneCountInString(textContent(x))
		}
		for c := x.FirstChild; c != nil; c = c.NextSibling {
			countLinks(c)
		}
	}
	countLinks(n)

	density := float64(linkChars) / float64(length)

	score := float64(length) * (1.0 - density)

	var countP func(*html.Node)
	paras := 0
	countP = func(x *html.Node) {
		if x.Type == html.ElementNode && (x.Data == "p" || x.Data == "pre" || x.Data == "blockquote") {
			paras++
		}
		for c := x.FirstChild; c != nil; c = c.NextSibling {
			countP(c)
		}
	}
	countP(n)
	score *= 1.0 + 0.1*float64(paras)

	score *= 1.0 + float64(strings.Count(text, ","))*0.005

	return score
}

func collectBlocks(n *html.Node) []string {
	var parts []string
	var walk func(*html.Node)
	walk = func(x *html.Node) {
		if x.Type == html.ElementNode && blockTags[x.Data] {

			if !hasBlockChild(x) {
				if t := normalizeWhitespace(textContent(x)); utf8.RuneCountInString(t) >= minBlockChars {
					parts = append(parts, t)
					return
				}
			}
		}
		if x.Type == html.TextNode {
			if t := normalizeWhitespace(x.Data); utf8.RuneCountInString(t) >= minBlockChars {
				parts = append(parts, t)
				return
			}
		}
		for c := x.FirstChild; c != nil; c = c.NextSibling {
			walk(c)
		}
	}
	walk(n)
	return parts
}

func hasBlockChild(n *html.Node) bool {
	for c := n.FirstChild; c != nil; c = c.NextSibling {
		if c.Type == html.ElementNode && blockTags[c.Data] {
			return true
		}
	}
	return false
}

func stripNoise(n *html.Node) {
	for c := n.FirstChild; c != nil; {
		next := c.NextSibling
		if c.Type == html.ElementNode && noisyTags[c.Data] {
			n.RemoveChild(c)
		} else {
			stripNoise(c)
		}
		c = next
	}
}

func textContent(n *html.Node) string {
	var b strings.Builder
	var walk func(*html.Node)
	walk = func(x *html.Node) {
		if x.Type == html.TextNode {
			b.WriteString(x.Data)
			b.WriteByte(' ')
		}
		for c := x.FirstChild; c != nil; c = c.NextSibling {
			walk(c)
		}
	}
	walk(n)
	return b.String()
}

func normalizeWhitespace(s string) string {
	return strings.Join(strings.Fields(s), " ")
}

func cleanText(s string) string { return normalizeWhitespace(s) }

func cleanTitle(title, domain string) string {
	t := normalizeWhitespace(title)
	if t == "" {
		return ""
	}

	host := strings.ToLower(strings.TrimPrefix(domain, "www."))
	if host == "" {
		return t
	}

	bare := host
	if i := strings.LastIndex(bare, "."); i > 0 {
		bare = bare[:i]
	}

	labels := strings.Split(bare, ".")
	aliases := map[string]bool{
		host: true, bare: true,
		strings.ReplaceAll(bare, ".", " "): true,
	}
	for _, l := range labels {
		if len(l) > 3 {
			aliases[l] = true
		}
	}

	for _, sep := range []string{" | ", " - ", " — ", " – ", " :: ", " » ", " // "} {
		if i := strings.LastIndex(t, sep); i > 0 {
			rest := strings.ToLower(strings.TrimSpace(t[i+len(sep):]))
			rest = strings.ReplaceAll(rest, "www.", "")
			if aliases[rest] {
				t = strings.TrimSpace(t[:i])
			}
		}
	}
	return t
}

func titleFromURL(rawURL string) string {
	u, err := parseURL(rawURL)
	if err != nil {
		return "Untitled"
	}

	seg, fromHost := "", false
	parts := strings.Split(strings.Trim(u.Path, "/"), "/")
	for i := len(parts) - 1; i >= 0; i-- {
		p := parts[i]
		if p == "" {
			continue
		}
		if isNumericOrID(p) && len(parts) > 1 {
			continue
		}
		seg = p
		break
	}
	if seg == "" {
		seg = u.Hostname()
		fromHost = true
	}

	if !fromHost {
		if i := strings.LastIndex(seg, "."); i > 0 && i < len(seg)-1 {
			if ext := seg[i+1:]; len(ext) <= 5 && !strings.ContainsAny(ext, " /") {
				seg = seg[:i]
			}
		}
	}

	r := strings.NewReplacer("-", " ", "_", " ", "%20", " ")
	if !fromHost {
		r = strings.NewReplacer("-", " ", "_", " ", ".", " ", "%20", " ")
	}
	seg = r.Replace(seg)
	seg = normalizeWhitespace(seg)
	if seg == "" {
		return "Untitled"
	}
	return strings.ToUpper(seg[:1]) + seg[1:]
}

func isNumericOrID(s string) bool {
	allDigits, hasDigit := true, false
	for _, r := range s {
		if r >= '0' && r <= '9' {
			hasDigit = true
			continue
		}
		allDigits = false
	}
	return allDigits || (len(s) >= 8 && hasDigit && !strings.ContainsAny(s, "-_"))
}

func excerptFrom(text string) string {
	const limit = 220
	t := normalizeWhitespace(text)
	if utf8.RuneCountInString(t) <= limit {
		return t
	}
	runes := []rune(t)
	cut := string(runes[:limit])

	if i := strings.LastIndexAny(cut, ".!?"); i > limit/2 {
		return strings.TrimSpace(cut[:i+1])
	}
	return strings.TrimSpace(cut) + "…"
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if strings.TrimSpace(v) != "" {
			return v
		}
	}
	return ""
}

func scrapeTitleWithRegex(body string) string {
	const open = "<title"
	i := strings.Index(strings.ToLower(body), open)
	if i < 0 {
		return ""
	}
	rest := body[i:]
	closeIdx := strings.Index(rest, ">")
	if closeIdx < 0 {
		return ""
	}
	rest = rest[closeIdx+1:]
	end := strings.Index(strings.ToLower(rest), "</title>")
	if end < 0 {
		return ""
	}
	return normalizeWhitespace(rest[:end])
}
