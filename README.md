# gitlab-workhorse

Gitlab-workhorse is a smart reverse proxy for GitLab. It handles
"large" HTTP requests such as file downloads, file uploads, Git
push/pull and Git archive downloads.

For more information see ['A brief history of
gitlab-workhorse'][brief-history-blog].

## Usage

```
  gitlab-workhorse [OPTIONS]

Options:
  -authBackend string
    	Authentication/authorization backend (default "http://localhost:8080")
  -authSocket string
    	Optional: Unix domain socket to dial authBackend at
  -developmentMode
    	Allow to serve assets from Rails app
  -documentRoot string
    	Path to static files content (default "public")
  -listenAddr string
    	Listen address for HTTP server (default "localhost:8181")
  -listenNetwork string
    	Listen 'network' (tcp, tcp4, tcp6, unix) (default "tcp")
  -listenUmask int
    	Umask for Unix socket (default 0)
  -pprofListenAddr string
    	pprof listening address, e.g. 'localhost:6060'
  -proxyHeadersTimeout duration
    	How long to wait for response headers when proxying the request (default 1m0s)
  -version
    	Print version and exit
```

The 'auth backend' refers to the GitLab Rails application. The name is
a holdover from when gitlab-workhorse only handled Git push/pull over
HTTP.

Gitlab-workhorse can listen on either a TCP or a Unix domain socket. It
can also open a second listening TCP listening socket with the Go
[net/http/pprof profiler server](http://golang.org/pkg/net/http/pprof/).

### Relative URL support

If you are mounting GitLab at a relative URL, e.g.
`example.com/gitlab`, then you should also use this relative URL in
the `authBackend` setting:

```
gitlab-workhorse -authBackend http://localhost:8080/gitlab
```

## Installation

To install gitlab-workhorse you need [Go 1.5 or
newer](https://golang.org/dl).

To install into `/usr/local/bin` run `make install`.

```
make install
```

To install into `/foo/bin` set the PREFIX variable.

```
make install PREFIX=/foo
```

## Tests

Run the tests with:

```
make clean test
```

### Coverage / what to test

Each feature in gitlab-workhorse should have an integration test that
verifies that the feature 'kicks in' on the right requests and leaves
other requests unaffected. It is better to also have package-level tests
for specific behavior but the high-level integration tests should have
the first priority during development.

It is OK if a feature is only covered by integration tests.

## License

This code is distributed under the MIT license, see the LICENSE file.

[brief-history-blog]: https://about.gitlab.com/2016/04/12/a-brief-history-of-gitlab-workhorse/
