package hooks

const (
	// ReadWriteLegacyTrustFile enables the reading and writing of the legacy `.githooks.checksum` file
	// @todo This feature needs to be set to `false` and removed.
	ReadWriteLegacyTrustFile = true

	// ReadLegacyIgnoreFiles enables the reading of legacy ignore files `.ignore`.
	ReadLegacyIgnoreFiles = true
	// ReadLegacyIgnoreFileFixPatters add a '**/' to each pattern, because thats
	// what it needs to make legacy patterns compatible.
	ReadLegacyIgnoreFileFixPatters = true

	// InstallLegacyBinaries installs cli.sh into the binary directory in the install folder.
	// @todo This feature needs to be set to `false` and removed.
	InstallLegacyBinaries = true
)
