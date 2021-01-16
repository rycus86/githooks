package download

import (
	cm "rycus86/githooks/common"
)

// The deploy settings for Gitea.
type HttpDeploySettings struct {
	// Path template string which can contain
	// - `{{VersionTag}}` : The version tag to download.
	// - `{{Os}}` : The `runtime.GOOS` variable with the operating system.
	// - `{{Arch}}` : The `runtime.GOARCH` for type architecture.
	// pointing to the compressed archive of the Githooks binaries.
	// in the same url directory need to be a checksum file
	// and a checksum signature file.
	UrlTemplate string
	// If empty, the internal Githooks binary
	// embedded PGP is taken from `.deploy.pgp`.
	PublicPGP string
}

// Download downloads the Githooks from a template URL and
// extracts it into `dir`.
func (s *HttpDeploySettings) Download(versionTag string, dir string) error {
	cm.Panic("Not implemented.")

	return nil
}
