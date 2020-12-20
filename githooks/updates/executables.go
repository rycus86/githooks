package updates

// Binaries define all binaries used by githooks.
type Binaries struct {
	Installer string   // The installer binary.
	Others    []string // All other binaries except the installer.
	All       []string // All binaries.

	BinDir string // Directory where all binaries reside.
}
