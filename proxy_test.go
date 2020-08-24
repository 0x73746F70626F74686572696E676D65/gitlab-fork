package main

import (
	"bytes"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"regexp"
	"strings"
	"testing"
	"time"

	"gitlab.com/gitlab-org/gitlab-workhorse/internal/badgateway"
	"gitlab.com/gitlab-org/gitlab-workhorse/internal/helper"
	"gitlab.com/gitlab-org/gitlab-workhorse/internal/proxy"
	"gitlab.com/gitlab-org/gitlab-workhorse/internal/testhelper"
	"gitlab.com/gitlab-org/gitlab-workhorse/internal/upstream/roundtripper"
)

const testVersion = "123"

func newProxy(url string, rt http.RoundTripper) *proxy.Proxy {
	parsedURL := helper.URLMustParse(url)
	if rt == nil {
		rt = roundtripper.NewTestBackendRoundTripper(parsedURL)
	}
	return proxy.NewProxy(parsedURL, testVersion, rt)
}

func TestProxyRequest(t *testing.T) {
	ts := testhelper.TestServerWithHandler(regexp.MustCompile(`/url/path\z`), func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" {
			t.Fatal("Expected POST request")
		}

		if r.Header.Get("Custom-Header") != "test" {
			t.Fatal("Missing custom header")
		}

		if h := r.Header.Get("Gitlab-Workhorse"); h != testVersion {
			t.Fatalf("Missing GitLab-Workhorse header: want %q, got %q", testVersion, h)
		}

		if h := r.Header.Get("Gitlab-Workhorse-Proxy-Start"); !strings.HasPrefix(h, "1") {
			t.Fatalf("Expect Gitlab-Workhorse-Proxy-Start to start with 1, got %q", h)
		}

		var body bytes.Buffer
		io.Copy(&body, r.Body)
		if body.String() != "REQUEST" {
			t.Fatal("Expected REQUEST in request body")
		}

		w.Header().Set("Custom-Response-Header", "test")
		w.WriteHeader(202)
		fmt.Fprint(w, "RESPONSE")
	})

	httpRequest, err := http.NewRequest("POST", ts.URL+"/url/path", bytes.NewBufferString("REQUEST"))
	if err != nil {
		t.Fatal(err)
	}
	httpRequest.Header.Set("Custom-Header", "test")

	w := httptest.NewRecorder()
	newProxy(ts.URL, nil).ServeHTTP(w, httpRequest)
	testhelper.RequireResponseCode(t, w, 202)
	testhelper.RequireResponseBody(t, w, "RESPONSE")

	if w.Header().Get("Custom-Response-Header") != "test" {
		t.Fatal("Expected custom response header")
	}
}

func TestProxyError(t *testing.T) {
	httpRequest, err := http.NewRequest("POST", "/url/path", bytes.NewBufferString("REQUEST"))
	if err != nil {
		t.Fatal(err)
	}
	httpRequest.Header.Set("Custom-Header", "test")

	w := httptest.NewRecorder()
	newProxy("http://localhost:655575/", nil).ServeHTTP(w, httpRequest)
	testhelper.RequireResponseCode(t, w, 502)
	testhelper.RequireResponseBodyRegexp(t, w, regexp.MustCompile("dial tcp:.*invalid port.*"))
}

func TestProxyReadTimeout(t *testing.T) {
	ts := testhelper.TestServerWithHandler(nil, func(w http.ResponseWriter, r *http.Request) {
		time.Sleep(time.Minute)
	})

	httpRequest, err := http.NewRequest("POST", "http://localhost/url/path", nil)
	if err != nil {
		t.Fatal(err)
	}

	rt := badgateway.NewRoundTripper(false, &http.Transport{
		Proxy: http.ProxyFromEnvironment,
		Dial: (&net.Dialer{
			Timeout:   30 * time.Second,
			KeepAlive: 30 * time.Second,
		}).Dial,
		TLSHandshakeTimeout:   10 * time.Second,
		ResponseHeaderTimeout: time.Millisecond,
	})

	p := newProxy(ts.URL, rt)
	w := httptest.NewRecorder()
	p.ServeHTTP(w, httpRequest)
	testhelper.RequireResponseCode(t, w, 502)
	testhelper.RequireResponseBody(t, w, "GitLab is not responding")
}

func TestProxyHandlerTimeout(t *testing.T) {
	ts := testhelper.TestServerWithHandler(nil,
		http.TimeoutHandler(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			time.Sleep(time.Second)
		}), time.Millisecond, "Request took too long").ServeHTTP,
	)

	httpRequest, err := http.NewRequest("POST", "http://localhost/url/path", nil)
	if err != nil {
		t.Fatal(err)
	}

	w := httptest.NewRecorder()
	newProxy(ts.URL, nil).ServeHTTP(w, httpRequest)
	testhelper.RequireResponseCode(t, w, 503)
	testhelper.RequireResponseBody(t, w, "Request took too long")
}
