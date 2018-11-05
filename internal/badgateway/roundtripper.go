package badgateway

import (
	"bytes"
	"fmt"
	"io/ioutil"
	"net/http"
	"time"

	"gitlab.com/gitlab-org/gitlab-workhorse/internal/helper"
)

// Error is a custom error for pretty Sentry 'issues'
type sentryError struct{ error }

type roundTripper struct {
	next            http.RoundTripper
	developmentMode bool
}

// NewRoundTripper creates a RoundTripper with a provided underlying next transport
func NewRoundTripper(developmentMode bool, next http.RoundTripper) http.RoundTripper {
	return &roundTripper{next: next, developmentMode: developmentMode}
}

func (t *roundTripper) RoundTrip(r *http.Request) (res *http.Response, err error) {
	start := time.Now()
	res, err = t.next.RoundTrip(r)

	// httputil.ReverseProxy translates all errors from this
	// RoundTrip function into 500 errors. But the most likely error
	// is that the Rails app is not responding, in which case users
	// and administrators expect to see a 502 error. To show 502s
	// instead of 500s we catch the RoundTrip error here and inject a
	// 502 response.
	if err != nil {
		helper.LogError(
			r,
			&sentryError{fmt.Errorf("badgateway: failed after %.fs: %v", time.Since(start).Seconds(), err)},
		)

		message := "GitLab is not responding"
		if t.developmentMode {
			message = err.Error()
		}

		res = &http.Response{
			StatusCode: http.StatusBadGateway,
			Status:     http.StatusText(http.StatusBadGateway),

			Request:    r,
			ProtoMajor: r.ProtoMajor,
			ProtoMinor: r.ProtoMinor,
			Proto:      r.Proto,
			Header:     make(http.Header),
			Trailer:    make(http.Header),
			Body:       ioutil.NopCloser(bytes.NewBufferString(message)),
		}
		res.Header.Set("Content-Type", "text/plain")
		err = nil
	}
	return
}
