package ccm

import (
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"
	"rycus86/githooks/prompt"
)

// CmdContext is the context for the CLI.
type CmdContext struct {
	Cwd  string       // The current working directory.
	GitX *git.Context // The git context in the current working directory.

	InstallDir string // The install directory.
	CloneDir   string // The release clone dir inside the install dir.

	Log       cm.ILogContext  // The log context.
	PromptCtx prompt.IContext // The prompt context.

}
