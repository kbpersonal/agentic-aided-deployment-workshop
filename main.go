package main

import (
	"cmp"
	"context"
	"log"
	"net"
	"net/http"
	"os"
	"strings"
	"time"

	_ "tailscale.com/feature/identityfederation"
	"tailscale.com/ipn/store"
	_ "tailscale.com/ipn/store/kubestore"
	"tailscale.com/tsnet"
)

func main() {
	hostname, _ := os.Hostname()
	a := &app{hostname: hostname, mode: "localhost", started: time.Now(), now: time.Now, identify: identityFromHeaders}

	tsHostname := os.Getenv("TS_HOSTNAME")
	if tsHostname == "" {
		addr := net.JoinHostPort(cmp.Or(os.Getenv("HOST"), "127.0.0.1"), cmp.Or(os.Getenv("PORT"), "3000"))
		log.Printf("workshop app listening on http://%s", addr)
		log.Fatal(http.ListenAndServe(addr, a))
	}

	s := &tsnet.Server{Hostname: tsHostname, Dir: os.Getenv("TS_STATE_DIR"), UserLogf: log.Printf}
	if f := os.Getenv("TS_ID_TOKEN_FILE"); f != "" {
		tok, err := os.ReadFile(f)
		if err != nil {
			log.Fatal(err)
		}
		s.IDToken = strings.TrimSpace(string(tok))
	}
	if tag := os.Getenv("TS_TAG"); tag != "" {
		s.AdvertiseTags = []string{tag}
	}
	if st := os.Getenv("TS_STATE"); st != "" {
		ss, err := store.New(log.Printf, st)
		if err != nil {
			log.Fatal(err)
		}
		s.Store = ss
	}
	defer s.Close()
	a.hostname = tsHostname

	var ln net.Listener
	if svc := os.Getenv("TS_SERVICE"); svc != "" {
		sl, err := s.ListenService(svc, tsnet.ServiceModeHTTP{Port: 443, HTTPS: true})
		if err != nil {
			log.Fatal(err)
		}
		a.mode = "Tailscale Service " + svc
		log.Printf("serving https://%s", sl.FQDN)
		ln = sl
	} else {
		st, err := s.Up(context.Background())
		if err != nil {
			log.Fatal(err)
		}
		lc, err := s.LocalClient()
		if err != nil {
			log.Fatal(err)
		}
		if ln, err = s.ListenTLS("tcp", ":443"); err != nil {
			log.Fatal(err)
		}
		a.mode = "tailnet device"
		a.identify = func(r *http.Request) *identity {
			who, err := lc.WhoIs(r.Context(), r.RemoteAddr)
			if err != nil || who.Node.IsTagged() {
				return nil
			}
			return &identity{Login: who.UserProfile.LoginName, Name: who.UserProfile.DisplayName, ProfilePic: safeProfileURL(who.UserProfile.ProfilePicURL)}
		}
		log.Printf("serving https://%s", strings.TrimSuffix(st.Self.DNSName, "."))
	}

	if addr := os.Getenv("HEALTH_ADDR"); addr != "" {
		go func() { log.Fatal(http.ListenAndServe(addr, http.HandlerFunc(a.health))) }()
	}
	log.Fatal(http.Serve(ln, a))
}

func (a *app) health(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/health" {
		http.NotFound(w, r)
		return
	}
	a.ServeHTTP(w, r)
}
