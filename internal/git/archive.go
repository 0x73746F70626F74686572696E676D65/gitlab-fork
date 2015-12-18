/*
In this file we handle 'git archive' downloads
*/

package git

import (
	"../api"
	"../helper"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"time"
)

func GetArchive(a *api.API) http.Handler {
	return repoPreAuthorizeHandler(a, handleGetArchive)
}
func handleGetArchive(w http.ResponseWriter, r *http.Request, a *api.Response) {
	var format string
	urlPath := r.URL.Path
	switch filepath.Base(urlPath) {
	case "archive.zip":
		format = "zip"
	case "archive.tar":
		format = "tar"
	case "archive", "archive.tar.gz":
		format = "tar.gz"
	case "archive.tar.bz2":
		format = "tar.bz2"
	default:
		helper.Fail500(w, fmt.Errorf("handleGetArchive: invalid format: %s", urlPath))
		return
	}

	archiveFilename := path.Base(a.ArchivePath)

	if cachedArchive, err := os.Open(a.ArchivePath); err == nil {
		defer cachedArchive.Close()
		log.Printf("Serving cached file %q", a.ArchivePath)
		setArchiveHeaders(w, format, archiveFilename)
		// Even if somebody deleted the cachedArchive from disk since we opened
		// the file, Unix file semantics guarantee we can still read from the
		// open file in this process.
		http.ServeContent(w, r, "", time.Unix(0, 0), cachedArchive)
		return
	}

	// We assume the tempFile has a unique name so that concurrent requests are
	// safe. We create the tempfile in the same directory as the final cached
	// archive we want to create so that we can use an atomic link(2) operation
	// to finalize the cached archive.
	tempFile, err := prepareArchiveTempfile(path.Dir(a.ArchivePath), archiveFilename)
	if err != nil {
		helper.Fail500(w, fmt.Errorf("handleGetArchive: create tempfile: %v", err))
		return
	}
	defer tempFile.Close()
	defer os.Remove(tempFile.Name())

	compressCmd, archiveFormat := parseArchiveFormat(format)

	archiveCmd := gitCommand("", "git", "--git-dir="+a.RepoPath, "archive", "--format="+archiveFormat, "--prefix="+a.ArchivePrefix+"/", a.CommitId)
	archiveStdout, err := archiveCmd.StdoutPipe()
	if err != nil {
		helper.Fail500(w, fmt.Errorf("handleGetArchive: archive stdout: %v", err))
		return
	}
	defer archiveStdout.Close()
	if err := archiveCmd.Start(); err != nil {
		helper.Fail500(w, fmt.Errorf("handleGetArchive: start %v: %v", archiveCmd.Args, err))
		return
	}
	defer cleanUpProcessGroup(archiveCmd) // Ensure brute force subprocess clean-up

	var stdout io.ReadCloser
	if compressCmd == nil {
		stdout = archiveStdout
	} else {
		compressCmd.Stdin = archiveStdout

		stdout, err = compressCmd.StdoutPipe()
		if err != nil {
			helper.Fail500(w, fmt.Errorf("handleGetArchive: compress stdout: %v", err))
			return
		}
		defer stdout.Close()

		if err := compressCmd.Start(); err != nil {
			helper.Fail500(w, fmt.Errorf("handleGetArchive: start %v: %v", compressCmd.Args, err))
			return
		}
		defer compressCmd.Wait()

		archiveStdout.Close()
	}
	// Every Read() from stdout will be synchronously written to tempFile
	// before it comes out the TeeReader.
	archiveReader := io.TeeReader(stdout, tempFile)

	// Start writing the response
	setArchiveHeaders(w, format, archiveFilename)
	w.WriteHeader(200) // Don't bother with HTTP 500 from this point on, just return
	if _, err := io.Copy(w, archiveReader); err != nil {
		helper.LogError(fmt.Errorf("handleGetArchive: read: %v", err))
		return
	}
	if err := archiveCmd.Wait(); err != nil {
		helper.LogError(fmt.Errorf("handleGetArchive: archiveCmd: %v", err))
		return
	}
	if compressCmd != nil {
		if err := compressCmd.Wait(); err != nil {
			helper.LogError(fmt.Errorf("handleGetArchive: compressCmd: %v", err))
			return
		}
	}

	if err := finalizeCachedArchive(tempFile, a.ArchivePath); err != nil {
		helper.LogError(fmt.Errorf("handleGetArchive: finalize cached archive: %v", err))
		return
	}
}

func setArchiveHeaders(w http.ResponseWriter, format string, archiveFilename string) {
	w.Header().Add("Content-Disposition", fmt.Sprintf(`attachment; filename="%s"`, archiveFilename))
	if format == "zip" {
		w.Header().Add("Content-Type", "application/zip")
	} else {
		w.Header().Add("Content-Type", "application/octet-stream")
	}
	w.Header().Add("Content-Transfer-Encoding", "binary")
	w.Header().Add("Cache-Control", "private")
}

func parseArchiveFormat(format string) (*exec.Cmd, string) {
	switch format {
	case "tar":
		return nil, "tar"
	case "tar.gz":
		return exec.Command("gzip", "-c", "-n"), "tar"
	case "tar.bz2":
		return exec.Command("bzip2", "-c"), "tar"
	case "zip":
		return nil, "zip"
	}
	return nil, "unknown"
}

func prepareArchiveTempfile(dir string, prefix string) (*os.File, error) {
	if err := os.MkdirAll(dir, 0700); err != nil {
		return nil, err
	}
	return ioutil.TempFile(dir, prefix)
}

func finalizeCachedArchive(tempFile *os.File, archivePath string) error {
	if err := tempFile.Close(); err != nil {
		return err
	}
	return os.Link(tempFile.Name(), archivePath)
}
