package updates

import "rycus86/githooks/git"

// Binaries define all binaries used by githooks.
type Binaries struct {
	Installer string   // The installer binary.
	Others    []string // All other binaries except the installer.
	All       []string // All binaries.

	BinDir string // Directory where all binaries reside.
}

// Settings defines the settings on
// how to collect the executables (installer, cli & runner).
type Settings struct {
	// If the executables are build from
	// source or they are collected by accessing the releases
	// of the remote in the release clone.
	// (e.g. github/rycus86/githooks/releases for example.)
	DoBuildFromSource bool
}

// GetSettings gets the settings for the executables.
func GetSettings() (settings Settings) {
	gitx := git.Ctx()
	buildBinaries := gitx.GetConfig("githooks.buildFromSource", git.GlobalScope)
	if buildBinaries == "true" {
		settings.DoBuildFromSource = true
	}
	return
}
