package core

import (
	"math/bits"
	"strings"
	"unicode"
)

const SimHashDuplicateThreshold = 4

func SimHash64(text string) uint64 {
	tokens := tokenize(text)
	if len(tokens) == 0 {
		return 0
	}

	var acc [64]int
	for _, tok := range tokens {
		h := fnv1a64(tok)
		for i := 0; i < 64; i++ {
			if h&(1<<uint(i)) != 0 {
				acc[i]++
			} else {
				acc[i]--
			}
		}
	}

	var fp uint64
	for i := 0; i < 64; i++ {
		if acc[i] > 0 {
			fp |= 1 << uint(i)
		}
	}
	return fp
}

func HammingDistance(a, b uint64) int {
	return bits.OnesCount64(a ^ b)
}

func SimHashSimilar(a, b uint64) bool {

	if a == 0 || b == 0 {
		return false
	}
	return HammingDistance(a, b) <= SimHashDuplicateThreshold
}

func tokenize(text string) []string {
	fields := strings.FieldsFunc(strings.ToLower(text), func(r rune) bool {
		return !unicode.IsLetter(r) && !unicode.IsDigit(r)
	})
	out := make([]string, 0, len(fields))
	for _, f := range fields {
		if len(f) >= 2 {
			out = append(out, f)
		}
	}
	return out
}

func fnv1a64(s string) uint64 {
	const (
		offset64 = 14695981039346656037
		prime64  = 1099511628211
	)
	h := uint64(offset64)
	for i := 0; i < len(s); i++ {
		h ^= uint64(s[i])
		h *= prime64
	}
	return h
}

type DedupeTier int

const (
	DedupeNone DedupeTier = iota
	DedupeExactURL
	DedupeSimilarContent
)

func (t DedupeTier) String() string {
	switch t {
	case DedupeExactURL:
		return "exact-url"
	case DedupeSimilarContent:
		return "similar-content"
	default:
		return "none"
	}
}

type Fingerprint struct {
	ID      string
	URL     string
	SimHash uint64
}

type DedupeResult struct {
	Tier    DedupeTier
	MatchID string

	Distance int
}

func (d DedupeResult) Found() bool { return d.Tier != DedupeNone }

func FindDuplicate(existing []Fingerprint, url string, text string) DedupeResult {
	return FindDuplicateByHash(existing, url, SimHash64(text))
}

func FindDuplicateByHash(existing []Fingerprint, url string, candidateSimHash uint64) DedupeResult {
	candidate := Fingerprint{ID: "candidate", URL: normalizeURL(url), SimHash: candidateSimHash}

	if candidate.URL != "" {
		for _, f := range existing {
			if normalizeURL(f.URL) == candidate.URL {
				return DedupeResult{Tier: DedupeExactURL, MatchID: f.ID}
			}
		}
	}

	if candidate.SimHash != 0 {
		best := DedupeResult{}
		bestDist := 65
		for _, f := range existing {
			if f.SimHash == 0 {
				continue
			}
			if d := HammingDistance(candidate.SimHash, f.SimHash); d <= SimHashDuplicateThreshold {
				if d < bestDist {
					bestDist = d
					best = DedupeResult{Tier: DedupeSimilarContent, MatchID: f.ID, Distance: d}
				}
			}
		}
		if best.Found() {
			return best
		}
	}

	return DedupeResult{Tier: DedupeNone}
}

func NormalizeURL(raw string) string { return normalizeURL(raw) }

func normalizeURL(raw string) string {
	u := strings.TrimSpace(strings.ToLower(raw))
	if u == "" {
		return ""
	}
	u = strings.TrimPrefix(u, "https://")
	u = strings.TrimPrefix(u, "http://")
	if i := strings.Index(u, "#"); i >= 0 {
		u = u[:i]
	}
	if i := strings.Index(u, "?"); i >= 0 {

		q := u[i+1:]
		u = u[:i]
		if q != "" {
			var kept []string
			for _, pair := range strings.Split(q, "&") {
				kv := strings.SplitN(pair, "=", 2)
				if len(kv) != 2 {
					continue
				}
				if isTrackingParam(kv[0]) {
					continue
				}
				kept = append(kept, pair)
			}
			if len(kept) > 0 {
				u += "?" + strings.Join(kept, "&")
			}
		}
	}
	u = strings.TrimPrefix(u, "www.")
	return strings.TrimSuffix(u, "/")
}

func isTrackingParam(k string) bool {
	switch k {
	case "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content", "utm_id",
		"ref", "ref_src", "referrer", "fbclid", "gclid", "igshid", "mc_cid", "mc_eid",
		"s", "t", "si", "feature":
		return true
	}
	return false
}
