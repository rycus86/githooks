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

	SkipInstallIntoExisting bool

	OnlyServerHooks bool

	UseCoreHooksPath bool

	CloneURL    string
	CloneBranch string

	BuildFromSource bool
	BuildTags       []string

	InstallPrefix string
	TemplateDir   string

	UseStdin bool
}
