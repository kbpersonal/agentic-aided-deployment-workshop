package main

import (
	"encoding/json"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func testApp() *app {
	start := time.Date(2026, 7, 28, 12, 0, 0, 0, time.UTC)
	return &app{
		hostname: "demo-host",
		mode:     "localhost",
		started:  start,
		now:      func() time.Time { return start.Add(42 * time.Second) },
		identify: identityFromHeaders,
	}
}

func do(t *testing.T, method, path string, headers map[string]string) *httptest.ResponseRecorder {
	t.Helper()
	r := httptest.NewRequest(method, path, nil)
	for k, v := range headers {
		r.Header.Set(k, v)
	}
	w := httptest.NewRecorder()
	testApp().ServeHTTP(w, r)
	return w
}

func TestPageAndSecurityHeaders(t *testing.T) {
	w := do(t, "GET", "/", nil)
	body := w.Body.String()
	if w.Code != 200 || !strings.Contains(body, "Beyond localhost") || !strings.Contains(body, "No trusted identity forwarded") {
		t.Fatalf("unexpected page: %d %s", w.Code, body)
	}
	if w.Header().Get("X-Frame-Options") != "DENY" || !strings.Contains(w.Header().Get("Content-Security-Policy"), "default-src 'none'") {
		t.Fatalf("missing security headers: %v", w.Header())
	}
}

func TestForwardedIdentityIsEscaped(t *testing.T) {
	body := do(t, "GET", "/", map[string]string{
		"Tailscale-User-Login": "raj@example.com",
		"Tailscale-User-Name":  "<script>Raj</script>",
	}).Body.String()
	if strings.Contains(body, "<script>Raj</script>") || !strings.Contains(body, "&lt;script&gt;Raj&lt;/script&gt;") || !strings.Contains(body, "via Tailscale") {
		t.Fatalf("identity not rendered safely: %s", body)
	}
}

func TestIdentityFromHeaders(t *testing.T) {
	r := httptest.NewRequest("GET", "/", nil)
	if identityFromHeaders(r) != nil {
		t.Fatal("expected anonymous without a login")
	}
	r.Header.Set("Tailscale-User-Login", " raj@example.com ")
	r.Header.Set("Tailscale-User-Name", " Raj Singh ")
	r.Header.Set("Tailscale-User-Profile-Pic", "https://example.com/raj.png")
	got := *identityFromHeaders(r)
	want := identity{Login: "raj@example.com", Name: "Raj Singh", ProfilePic: "https://example.com/raj.png"}
	if got != want {
		t.Fatalf("got %+v, want %+v", got, want)
	}
	r.Header.Set("Tailscale-User-Profile-Pic", "javascript:alert(1)")
	if identityFromHeaders(r).ProfilePic != "" {
		t.Fatal("unsafe profile URL accepted")
	}
}

func TestHealthHeadNotFoundAndMethods(t *testing.T) {
	var health map[string]any
	json.NewDecoder(do(t, "GET", "/health", nil).Body).Decode(&health)
	if health["status"] != "ok" || health["service"] != "agentic-aided-deployment-workshop" || health["uptimeSeconds"] != float64(42) {
		t.Fatalf("bad health: %v", health)
	}
	if do(t, "HEAD", "/", nil).Code != 200 {
		t.Fatal("HEAD not allowed")
	}
	if do(t, "GET", "/missing", nil).Code != 404 {
		t.Fatal("expected 404")
	}
	w := do(t, "POST", "/", nil)
	if w.Code != 405 || w.Header().Get("Allow") != "GET, HEAD" {
		t.Fatalf("expected 405 with Allow, got %d %v", w.Code, w.Header())
	}
}
