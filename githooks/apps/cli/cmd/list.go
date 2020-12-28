package cmd

import (
	"github.com/spf13/cobra"
)

// listCmd represents the list command.
var listCmd = &cobra.Command{
	Use:   "list",
	Short: "Lists the active hooks in the current repository.",
	Long: `
Lists the active hooks in the current repository along with their state.

git hooks list [type]

	If 'type' is given, then it only lists the hooks for that trigger event.
	This command needs to be run at the root of a repository.`,
	Run: runList,
}

func runList(cmd *cobra.Command, args []string) {

}

func init() { // nolint: gochecknoinits
	rootCmd.AddCommand(listCmd)
}
