package ingest

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/cull-app/cull/core"
)

const (
	FetchTimeout = 5 * time.Second

	MaxHTMLBytes = 5 << 20

	MaxRedirects = 3

	ReadTimeout = 3 * time.Second
)

const UserAgent = "CULL/1.0 (+https://github.com/cull-app/cull)"

var ErrBlocked = errors.New("ingest: url blocked")

type Document struct {
	URL        string
	Domain     string
	Title      string
	Excerpt    string
	Readable   string
	FaviconURL string

	Method string
}

type Fetcher struct {
	client  *http.Client
	resolve func(ctx context.Context, host string) ([]net.IP, error)

	allowPrivate bool
}

func NewFetcher() *Fetcher {
	f := &Fetcher{
		resolve: defaultResolve,
	}
	f.client = &http.Client{
		Timeout: FetchTimeout,

		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			if len(via) >= MaxRedirects {
				return fmt.Errorf("%w: too many redirects", ErrBlocked)
			}
			return f.guardHost(req.Context(), req.URL)
		},
	}
	return f
}

func defaultResolve(ctx context.Context, host string) ([]net.IP, error) {
	return net.DefaultResolver.LookupIP(ctx, "ip", host)
}

func NewFetcherWithResolver(resolve func(context.Context, string) ([]net.IP, error)) *Fetcher {
	f := NewFetcher()
	f.resolve = resolve
	return f
}

func (f *Fetcher) Fetch(ctx context.Context, rawURL string) (Document, error) {
	u, err := ValidateURL(rawURL)
	if err != nil {
		return Document{}, err
	}

	ctx, cancel := context.WithTimeout(ctx, FetchTimeout)
	defer cancel()

	if err := f.guardHost(ctx, u); err != nil {
		return Document{}, err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u.String(), nil)
	if err != nil {
		return documentForURL(u.String()), fmt.Errorf("ingest: build request: %w", err)
	}
	req.Header.Set("User-Agent", UserAgent)
	req.Header.Set("Accept", "text/html,application/xhtml+xml;q=0.9,*/*;q=0.8")
	req.Header.Set("Accept-Language", "en-US,en;q=0.9")

	req.Header.Set("Accept-Encoding", "identity")

	resp, err := f.client.Do(req)
	if err != nil {
		return documentForURL(u.String()), fmt.Errorf("ingest: fetch %s: %w", u.Host, err)
	}
	defer resp.Body.Close()

	if err := f.guardHost(ctx, resp.Request.URL); err != nil {
		return documentForURL(u.String()), err
	}

	if resp.StatusCode >= 400 {
		return documentForURL(u.String()),
			fmt.Errorf("ingest: %s returned %s", u.Host, resp.Status)
	}

	body, err := io.ReadAll(io.LimitReader(resp.Body, MaxHTMLBytes))
	if err != nil && len(body) == 0 {
		return documentForURL(u.String()), fmt.Errorf("ingest: read body: %w", err)
	}

	return Extract(resp.Request.URL.String(), body), nil
}

func documentForURL(rawURL string) Document {
	title := titleFromURL(rawURL)
	return Document{
		URL:     rawURL,
		Domain:  DomainOf(rawURL),
		Title:   title,
		Excerpt: title,
		Method:  MethodURL,
	}
}

func ValidateURL(rawURL string) (*url.URL, error) {
	raw := strings.TrimSpace(rawURL)
	if raw == "" {
		return nil, fmt.Errorf("%w: empty url", ErrBlocked)
	}

	if !strings.Contains(raw, "://") {
		raw = "https://" + raw
	}

	u, err := url.Parse(raw)
	if err != nil {
		return nil, fmt.Errorf("%w: unparseable url: %v", ErrBlocked, err)
	}

	scheme := strings.ToLower(u.Scheme)
	if scheme != "http" && scheme != "https" {

		return nil, fmt.Errorf("%w: scheme %q is not allowed", ErrBlocked, scheme)
	}
	if u.Hostname() == "" {
		return nil, fmt.Errorf("%w: no host", ErrBlocked)
	}
	return u, nil
}

func (f *Fetcher) guardHost(ctx context.Context, u *url.URL) error {
	if f.allowPrivate {
		return nil
	}

	host := u.Hostname()
	if host == "" {
		return fmt.Errorf("%w: no host", ErrBlocked)
	}

	if ip := net.ParseIP(host); ip != nil {
		if isBlockedIP(ip) {
			return fmt.Errorf("%w: %s is a private address", ErrBlocked, ip)
		}
		return nil
	}

	ips, err := f.resolve(ctx, host)
	if err != nil {
		return fmt.Errorf("%w: cannot resolve %s: %v", ErrBlocked, host, err)
	}
	if len(ips) == 0 {
		return fmt.Errorf("%w: %s resolved to nothing", ErrBlocked, host)
	}

	for _, ip := range ips {
		if isBlockedIP(ip) {
			return fmt.Errorf("%w: %s resolves to private address %s", ErrBlocked, host, ip)
		}
	}
	return nil
}

var blockedCIDRs = mustCIDRs(
	"100.64.0.0/10",
	"192.0.0.0/24",
	"198.18.0.0/15",
	"240.0.0.0/4",
	"::/128",
	"64:ff9b::/96",
	"100::/64",
	"2001:db8::/32",
	"fc00::/7",
	"fe80::/10",
	"ff00::/8",
)

func mustCIDRs(cidrs ...string) []*net.IPNet {
	out := make([]*net.IPNet, 0, len(cidrs))
	for _, c := range cidrs {
		_, n, err := net.ParseCIDR(c)
		if err != nil {
			panic("ingest: bad CIDR " + c + ": " + err.Error())
		}
		out = append(out, n)
	}
	return out
}

func isBlockedIP(ip net.IP) bool {
	if ip == nil {
		return true
	}
	if ip.IsLoopback() || ip.IsPrivate() ||
		ip.IsLinkLocalUnicast() || ip.IsLinkLocalMulticast() ||
		ip.IsUnspecified() || ip.IsInterfaceLocalMulticast() ||
		ip.IsMulticast() {
		return true
	}
	for _, n := range blockedCIDRs {
		if n.Contains(ip) {
			return true
		}
	}
	return false
}

func IsBlockedIP(ip net.IP) bool { return isBlockedIP(ip) }

func DomainOf(rawURL string) string { return core.DomainOf(rawURL) }

func parseURL(raw string) (*url.URL, error) { return url.Parse(raw) }
