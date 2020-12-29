package cmd

import (
	"rycus86/githooks/git"
	"rycus86/githooks/prompt"
)

// Settings are the settings for the cli.
type Settings struct {
	Cwd  string       // The current working directory.
	GitX *git.Context // The git context in the current working directory.

	InstallDir string // The install directory.
	CloneDir   string // The release clone dir inside the install dir.

	PromptCtx prompt.IContext // The prompt context.

}
