package staticpages

import (
	"../helper"
	"fmt"
	"io/ioutil"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

func TestIfErrorPageIsPresented(t *testing.T) {
	dir, err := ioutil.TempDir("", "error_page")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(dir)

	errorPage := "ERROR"
	ioutil.WriteFile(filepath.Join(dir, "404.html"), []byte(errorPage), 0600)

	w := httptest.NewRecorder()
	h := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(404)
		fmt.Fprint(w, "Not Found")
	})
	st := &Static{dir}
	st.ErrorPages(h).ServeHTTP(w, nil)
	w.Flush()

	helper.AssertResponseCode(t, w, 404)
	helper.AssertResponseBody(t, w, errorPage)
}

func TestIfErrorPassedIfNoErrorPageIsFound(t *testing.T) {
	dir, err := ioutil.TempDir("", "error_page")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(dir)

	w := httptest.NewRecorder()
	errorResponse := "ERROR"
	h := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(404)
		fmt.Fprint(w, errorResponse)
	})
	st := &Static{dir}
	st.ErrorPages(h).ServeHTTP(w, nil)
	w.Flush()

	helper.AssertResponseCode(t, w, 404)
	helper.AssertResponseBody(t, w, errorResponse)
}
