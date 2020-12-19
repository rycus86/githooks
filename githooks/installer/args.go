package main

// Arguments repesents all CLI arguments for the installer.
type Arguments struct {
	config string

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
	BuildFlags      []string

	InstallPrefix string
	TemplateDir   string

	UseStdin bool
}
