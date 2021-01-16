package main

// Arguments repesents all CLI arguments for the installer.
type Arguments struct {
	Config string

	InternalAutoUpdate   bool
	InternalPostDispatch bool

	InternalUpdateFromVersion string   // Build version we are updating from.
	InternalUpdateTo          string   // Commit SHA to update local branch to remote.
	InternalBinaries          []string // Binaries which need to get installed.

	DryRun         bool
	NonInteractive bool

	SkipInstallIntoExisting bool // Skip install into existing repositories.

	OnlyServerHooks bool // Only maintain server hooks.

	UseCoreHooksPath bool // Use the `core.hooksPath` for the template dir.

	InstallPrefix string // Install prefix for Githooks.
	TemplateDir   string // Template dir to use for the hooks.

	CloneURL       string // Clone URL of the Githooks repository.
	CloneBranch    string // Clone branch for Githooks repository.
	DeployAPI      string // Deploy API to use for auto detection of deploy settings.
	DeploySettings string // Deploy settings YAML file.

	BuildFromSource bool     // If we build the install/update from source.
	BuildTags       []string // Go build tags.

	UseStdin bool
}
