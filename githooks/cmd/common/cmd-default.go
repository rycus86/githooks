package ccm

import (
	cm "rycus86/githooks/common"
	"rycus86/githooks/hooks"
	strs "rycus86/githooks/strings"
	"strings"

	"github.com/spf13/cobra"
)

// SetCommandDefaults sets defaults for the command 'cmd'.
func SetCommandDefaults(log cm.ILogContext, cmd *cobra.Command) *cobra.Command {
	cmd.DisableFlagsInUseLine = true
	cmd.SilenceUsage = true
	cmd.SilenceErrors = true

	if cmd.PreRun == nil {
		cmd.PreRun = PanicIfAnyArgs(log)
	}

	if cmd.Run == nil {
		cmd.Run = PanicWrongArgs(log)
	}

	return cmd
}

// cmd.AssertRepoRoot asserts that the current directory is in a repository.
// Returns repository root and its git directory.
func AssertRepoRoot(ctx *CmdContext) (string, string) {
	repoRoot, gitDir, err := ctx.GitX.GetRepoRoot()

	ctx.Log.AssertNoErrorPanicF(err,
		"Current working directory '%s' is neither inside a worktree\n"+
			"nor inside a bare repository.",
		ctx.Cwd)

	return repoRoot, gitDir
}

// Gets a list of formatted hook names.
func GetFormattedHookList(indent string) string {
	return strings.Join(strs.Map(hooks.ManagedHookNames,
		func(s string) string {
			return strs.Fmt("%s%s '%s'", indent, ListItemLiteral, s)
		}),
		"\n")
}
