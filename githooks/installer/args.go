package main

// Arguments repesents all CLI arguments for the installer.
type Arguments struct {
	Config string

	InternalAutoUpdate bool
	InternalPostUpdate bool
	InternalUpdateTo   string
	InternalBinaries   []string

	DryRun         bool
	NonInteractive bool

	SingleInstall bool

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
