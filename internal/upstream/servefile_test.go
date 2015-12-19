package upstream

import (
	"../helper"
	"bytes"
	"compress/gzip"
	"io/ioutil"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

func TestServingNonExistingFile(t *testing.T) {
	dir := "/path/to/non/existing/directory"
	httpRequest, _ := http.NewRequest("GET", "/file", nil)

	w := httptest.NewRecorder()
	handleServeFile(dir, "/", CacheDisabled, nil).ServeHTTP(w, httpRequest)
	helper.AssertResponseCode(t, w, 404)
}

func TestServingDirectory(t *testing.T) {
	dir, err := ioutil.TempDir("", "deploy")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(dir)

	httpRequest, _ := http.NewRequest("GET", "/file", nil)
	w := httptest.NewRecorder()
	handleServeFile(dir, "/", CacheDisabled, nil).ServeHTTP(w, httpRequest)
	helper.AssertResponseCode(t, w, 404)
}

func TestServingMalformedUri(t *testing.T) {
	dir := "/path/to/non/existing/directory"
	httpRequest, _ := http.NewRequest("GET", "/../../../static/file", nil)

	w := httptest.NewRecorder()
	handleServeFile(dir, "/", CacheDisabled, nil).ServeHTTP(w, httpRequest)
	helper.AssertResponseCode(t, w, 404)
}

func TestExecutingHandlerWhenNoFileFound(t *testing.T) {
	dir := "/path/to/non/existing/directory"
	httpRequest, _ := http.NewRequest("GET", "/file", nil)

	executed := false
	handleServeFile(dir, "/", CacheDisabled, http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
		executed = (r == httpRequest)
	})).ServeHTTP(nil, httpRequest)
	if !executed {
		t.Error("The handler should get executed")
	}
}

func TestServingTheActualFile(t *testing.T) {
	dir, err := ioutil.TempDir("", "deploy")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(dir)

	httpRequest, _ := http.NewRequest("GET", "/file", nil)

	fileContent := "STATIC"
	ioutil.WriteFile(filepath.Join(dir, "file"), []byte(fileContent), 0600)

	w := httptest.NewRecorder()
	handleServeFile(dir, "/", CacheDisabled, nil).ServeHTTP(w, httpRequest)
	helper.AssertResponseCode(t, w, 200)
	if w.Body.String() != fileContent {
		t.Error("We should serve the file: ", w.Body.String())
	}
}

func testServingThePregzippedFile(t *testing.T, enableGzip bool) {
	dir, err := ioutil.TempDir("", "deploy")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(dir)

	httpRequest, _ := http.NewRequest("GET", "/file", nil)

	if enableGzip {
		httpRequest.Header.Set("Accept-Encoding", "gzip, deflate")
	}

	fileContent := "STATIC"

	var fileGzipContent bytes.Buffer
	fileGzip := gzip.NewWriter(&fileGzipContent)
	fileGzip.Write([]byte(fileContent))
	fileGzip.Close()

	ioutil.WriteFile(filepath.Join(dir, "file.gz"), fileGzipContent.Bytes(), 0600)
	ioutil.WriteFile(filepath.Join(dir, "file"), []byte(fileContent), 0600)

	w := httptest.NewRecorder()
	handleServeFile(dir, "/", CacheDisabled, nil).ServeHTTP(w, httpRequest)
	helper.AssertResponseCode(t, w, 200)
	if enableGzip {
		helper.AssertResponseHeader(t, w, "Content-Encoding", "gzip")
		if bytes.Compare(w.Body.Bytes(), fileGzipContent.Bytes()) != 0 {
			t.Error("We should serve the pregzipped file")
		}
	} else {
		helper.AssertResponseCode(t, w, 200)
		helper.AssertResponseHeader(t, w, "Content-Encoding", "")
		if w.Body.String() != fileContent {
			t.Error("We should serve the file: ", w.Body.String())
		}
	}
}

func TestServingThePregzippedFile(t *testing.T) {
	testServingThePregzippedFile(t, true)
}

func TestServingThePregzippedFileWithoutEncoding(t *testing.T) {
	testServingThePregzippedFile(t, false)
}
