package cmd

import "github.com/spf13/cobra"

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
