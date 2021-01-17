package download

import (
	"bytes"
	"html/template"
	"io/ioutil"
	"os"
	"path"
	"runtime"
	cm "rycus86/githooks/common"
	"strings"
)

// The deploy settings for Gitea.
type LocalDeploySettings struct {
	// Path template string which can contain
	// - `{{VersionTag}}` : The version tag to download.
	// - `{{Version}}` : The version to download (removed prefix 'v' of `VersionTag`).
	// - `{{Os}}` : The `runtime.GOOS` variable with the operating system.
	// - `{{Arch}}` : The `runtime.GOARCH` for type architecture.
	// pointing to the compressed archive of the Githooks binaries.
	// In the same directory need to be a checksum file
	// `githooks.checksums`
	// and a checksum signature file.
	// `githooks.checksums.sig` which is validated using
	// the `PublicPGP`.
	PathTemplate string

	// If empty, the internal Githooks binary
	// embedded PGP is taken from `.deploy.pgp`.
	PublicPGP string
}

// Download downloads the Githooks from a template URL and
// extracts it into `dir`.
func (s *LocalDeploySettings) Download(versionTag string, dir string) error {
	// Copy everything to director `dir`
	pathTmpl := template.Must(template.New("").Parse(s.PathTemplate))

	var buf bytes.Buffer
	err := pathTmpl.Execute(&buf, struct {
		VersionTag string
		Version    string
		Os         string
		Arch       string
	}{
		VersionTag: versionTag,
		Version:    strings.TrimPrefix(versionTag, "v"),
		Os:         runtime.GOOS,
		Arch:       runtime.GOARCH,
	})

	if err != nil {
		return cm.ErrorF("Could not format path template '%s'.", s.PathTemplate)
	}

	targetFile := buf.String()
	targetExtension := ""
	switch {
	case strings.HasSuffix(targetFile, ".tar.gz"):
		targetExtension = ".tar.gz"
	case strings.HasSuffix(targetFile, ".zip"):
		targetExtension = ".zip"
	default:
		return cm.Error("Archive type of file '%s' not supporeted.", targetFile)
	}

	targetDir := path.Dir(targetFile)

	// Read the checksumFile into memory
	checksumFile := path.Join(targetDir, githooksChecksumFile)
	checksumBytes, err := ioutil.ReadFile(checksumFile)
	if err != nil {
		return err
	}

	checksumFileSignature := path.Join(targetDir, githooksChecksumSignatureFile)
	checksumSigF, err := os.Open(checksumFileSignature)
	if err != nil {
		return err
	}
	err = cm.VerifyFile(bytes.NewReader(checksumBytes), checksumSigF, s.PublicPGP)
	if err != nil {
		return err
	}

	// Validate checksum.
	err = checkChecksum(targetFile, checksumBytes)
	if err != nil {
		return cm.CombineErrors(err,
			cm.ErrorF("Checksum validation failed."))
	}

	// Extract the file.
	err = Extract(targetFile, targetExtension, dir)
	if err != nil {
		return cm.CombineErrors(err,
			cm.ErrorF("Archive extraction from '%s' failed.", targetFile))
	}

	return nil
}
