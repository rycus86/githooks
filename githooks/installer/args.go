package main

// Arguments repesents all CLI arguments for the installer.
type Arguments struct {
	internalInstall    bool
	internalAutoUpdate bool
	internalPostUpdate bool
	internalUpdateTo   string

	dryRun         bool
	nonInteractive bool

	singleInstall bool

	skipInstallIntoExisting bool

	onlyServerHooks bool

	useCoreHooksPath bool

	cloneURL        string
	cloneBranch     string
	buildFromSource bool

	installPrefix string
	templateDir   string
}

// GetDefaultArgs gets all default CLI arguments.
func GetDefaultArgs() Arguments {
	return Arguments{}
}
