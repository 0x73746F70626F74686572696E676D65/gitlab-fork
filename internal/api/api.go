package api

import (
	"../helper"
	"../proxy"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"net/http"
	"net/url"
	"strings"
)

type API struct {
	*http.Client
	URL     *url.URL
	Version string
}

type HandleFunc func(http.ResponseWriter, *http.Request, *Response)

type Response struct {
	// GL_ID is an environment variable used by gitlab-shell hooks during 'git
	// push' and 'git pull'
	GL_ID string
	// RepoPath is the full path on disk to the Git repository the request is
	// about
	RepoPath string
	// ArchivePath is the full path where we should find/create a cached copy
	// of a requested archive
	ArchivePath string
	// ArchivePrefix is used to put extracted archive contents in a
	// subdirectory
	ArchivePrefix string
	// CommitId is used do prevent race conditions between the 'time of check'
	// in the GitLab Rails app and the 'time of use' in gitlab-workhorse.
	CommitId string
	// StoreLFSPath is provided by the GitLab Rails application
	// to mark where the tmp file should be placed
	StoreLFSPath string
	// LFS object id
	LfsOid string
	// LFS object size
	LfsSize int64
	// TmpPath is the path where we should store temporary files
	// This is set by authorization middleware
	TempPath string
}

func (api *API) newRequest(r *http.Request, body io.Reader, suffix string) (*http.Request, error) {
	url := *api.URL // Make a copy of api.URL
	url.Path = r.URL.RequestURI() + suffix
	authReq := &http.Request{
		Method: r.Method,
		URL:    &url,
		Header: proxy.HeaderClone(r.Header),
	}
	if body != nil {
		authReq.Body = ioutil.NopCloser(body)
	}

	// Clean some headers when issuing a new request without body
	if body == nil {
		authReq.Header.Del("Content-Type")
		authReq.Header.Del("Content-Encoding")
		authReq.Header.Del("Content-Length")
		authReq.Header.Del("Content-Disposition")
		authReq.Header.Del("Accept-Encoding")

		// Hop-by-hop headers. These are removed when sent to the backend.
		// http://www.w3.org/Protocols/rfc2616/rfc2616-sec13.html
		authReq.Header.Del("Transfer-Encoding")
		authReq.Header.Del("Connection")
		authReq.Header.Del("Keep-Alive")
		authReq.Header.Del("Proxy-Authenticate")
		authReq.Header.Del("Proxy-Authorization")
		authReq.Header.Del("Te")
		authReq.Header.Del("Trailers")
		authReq.Header.Del("Upgrade")
	}

	// Also forward the Host header, which is excluded from the Header map by the http libary.
	// This allows the Host header received by the backend to be consistent with other
	// requests not going through gitlab-workhorse.
	authReq.Host = r.Host
	// Set a custom header for the request. This can be used in some
	// configurations (Passenger) to solve auth request routing problems.
	authReq.Header.Set("Gitlab-Workhorse", api.Version)

	return authReq, nil
}

func (api *API) PreAuthorizeHandler(h HandleFunc, suffix string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		authReq, err := api.newRequest(r, nil, suffix)
		if err != nil {
			helper.Fail500(w, fmt.Errorf("preAuthorizeHandler: newUpstreamRequest: %v", err))
			return
		}

		authResponse, err := api.Do(authReq)
		if err != nil {
			helper.Fail500(w, fmt.Errorf("preAuthorizeHandler: do %v: %v", authReq.URL.Path, err))
			return
		}
		defer authResponse.Body.Close()

		if authResponse.StatusCode != 200 {
			// The Git request is not allowed by the backend. Maybe the
			// client needs to send HTTP Basic credentials.  Forward the
			// response from the auth backend to our client. This includes
			// the 'WWW-Authenticate' header that acts as a hint that
			// Basic auth credentials are needed.
			for k, v := range authResponse.Header {
				// Accomodate broken clients that do case-sensitive header lookup
				if k == "Www-Authenticate" {
					w.Header()["WWW-Authenticate"] = v
				} else {
					w.Header()[k] = v
				}
			}
			w.WriteHeader(authResponse.StatusCode)
			io.Copy(w, authResponse.Body)
			return
		}

		a := &Response{}
		// The auth backend validated the client request and told us additional
		// request metadata. We must extract this information from the auth
		// response body.
		if err := json.NewDecoder(authResponse.Body).Decode(a); err != nil {
			helper.Fail500(w, fmt.Errorf("preAuthorizeHandler: decode authorization response: %v", err))
			return
		}
		// Don't hog a TCP connection in CLOSE_WAIT, we can already close it now
		authResponse.Body.Close()

		// Negotiate authentication (Kerberos) may need to return a WWW-Authenticate
		// header to the client even in case of success as per RFC4559.
		for k, v := range authResponse.Header {
			// Case-insensitive comparison as per RFC7230
			if strings.EqualFold(k, "WWW-Authenticate") {
				w.Header()[k] = v
			}
		}

		h(w, r, a)
	}
}
