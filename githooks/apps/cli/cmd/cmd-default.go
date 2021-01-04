package cmd

import (
	"rycus86/githooks/hooks"
	strs "rycus86/githooks/strings"
	"strings"

	"github.com/spf13/cobra"
)

// setCommandDefaults sets defaults for the command 'cmd'.
func setCommandDefaults(cmd *cobra.Command) *cobra.Command {
	cmd.DisableFlagsInUseLine = true
	cmd.SilenceUsage = true
	cmd.SilenceErrors = true

	if cmd.PreRun == nil {
		cmd.PreRun = panicIfAnyArgs
	}

	if cmd.Run == nil {
		cmd.Run = panicWrongArgs
	}

	return cmd
}

func assertRepoRoot(settings *Settings) (string, string) {
	repoRoot, gitDir, err := settings.GitX.GetRepoRoot()

	log.AssertNoErrorPanicF(err,
		"Current working directory '%s' is neither inside a worktree\n"+
			"nor inside a bare repository.",
		settings.Cwd)

	return repoRoot, gitDir
}

func getFormattedHookList(indent string) string {
	return strings.Join(strs.Map(hooks.ManagedHookNames,
		func(s string) string {
			return strs.Fmt("%s%s '%s'", indent, ListItemLiteral, s)
		}),
		"\n")
}
