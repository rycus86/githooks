package cmd

import (
	"github.com/spf13/cobra"
)

// enableCmd represents the enable command.
var enableCmd = &cobra.Command{
	Use:   "enable",
	Short: "Enables a previously disabled hook in the current repository.",
	Long: `
Enables a hook or hooks in the current repository.

git hooks enable [--shared] [trigger] [hook-script]
git hooks enable [--shared] [hook-script]
git hooks enable [--shared] [trigger]

	The 'trigger' parameter should be the name of the Git event if given.
	The 'hook-script' can be the name of the file to enable, or its
	relative path, or an absolute path, we will try to find it.
	If the '--shared' parameter is given as the first argument,
	hooks in the shared repositories will be enabled,
	otherwise they are looked up in the current local repository.`,
	Run: runEnable,
}

func runEnable(cmd *cobra.Command, args []string) {

}

// disableCmd represents the disable command.
var disableCmd = &cobra.Command{
	Use:   "disable",
	Short: "Disables a hook in the current repository.",
	Long: `
Disables a hook in the current repository.

git hooks disable [--shared] [trigger] [hook-script]
git hooks disable [--shared] [hook-script]
git hooks disable [--shared] [trigger]
git hooks disable [-a|--all]
git hooks disable [-r|--reset]

	The 'trigger' parameter should be the name of the Git event if given.
	The 'hook-script' can be the name of the file to disable, or its
	relative path, or an absolute path, we will try to find it.
	If the '--shared' parameter is given as the first argument,
	hooks in the shared repositories will be disabled,
	otherwise they are looked up in the current local repository.
	The '--all' parameter on its own will disable running any Githooks
	in the current repository, both existing ones and any future hooks.
	The '--reset' parameter is used to undo this, and let hooks run again.`,
	Run: runDisable,
}

func runDisable(cmd *cobra.Command, args []string) {

}

func init() { // nolint: gochecknoinits
	rootCmd.AddCommand(enableCmd)
	rootCmd.AddCommand(disableCmd)
}
