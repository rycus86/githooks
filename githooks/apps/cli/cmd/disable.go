package cmd

import (
	"rycus86/githooks/git"
	"rycus86/githooks/hooks"

	"github.com/spf13/cobra"
)

var disableCmd = &cobra.Command{
	Use:   "disable [flags]",
	Short: "Disables Githooks in the current repository.",
	Long: `Disables running any Githooks in the current repository.

LFS hooks and replaced previous hooks are still executed.`,
	PreRun: panicIfAnyArgs,
	Run: func(cmd *cobra.Command, args []string) {
		runDisable(disableOpts.Reset)
	}}

type disableOptions struct {
	Reset bool
}

var disableOpts disableOptions

func runDisable(reset bool) {
	assertRepoRoot(&settings)

	if reset {
		err := settings.GitX.UnsetConfig(hooks.GitCK_Disable, git.LocalScope)
		log.AssertNoErrorPanic(err, "Could not unset Git config '%s'.", hooks.GitCK_Disable)
		log.InfoF("Enabled Githooks in the current repository.")

	} else {
		err := settings.GitX.SetConfig(hooks.GitCK_Disable, true, git.LocalScope)
		log.AssertNoErrorPanic(err, "Could not unset Git config '%s'.", hooks.GitCK_Disable)
		log.InfoF("Disabled Githooks in the current repository.")
	}
}

func init() { // nolint: gochecknoinits
	disableCmd.Flags().BoolVar(&disableOpts.Reset, "reset", false,
		`Resets the disable setting and enables running
hooks by Githooks again.`)

	rootCmd.AddCommand(setCommandDefaults(disableCmd))
}
