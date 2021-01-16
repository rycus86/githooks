package download

import (
	cm "rycus86/githooks/common"
)

// The deploy settings for Gitea.
type HttpDeploySettings struct {
	// Url template string which can contain
	// - `{{version}}` : The version to download.
	// - `{{os}}` : The `runtime.GOOS` variable with the operating system.
	// - `{{arch}}` : The `runtime.GOARCH` for type architecture.
	UrlTemplate string
}

// Download downloads the Githooks from a template URL and
// extracts it into `dir`.
func (s *HttpDeploySettings) Download(versionTag string, dir string) error {
	cm.Panic("Not implemented.")

	return nil
}
