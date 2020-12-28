package cmd

import (
	"github.com/spf13/cobra"
)

// ignoreCmd represents the ignore command.
var ignoreCmd = &cobra.Command{
	Use:   "ignore",
	Short: "Manages Githooks ignore files in the current repository.",
	Long: `
Adds new file name patterns to the Githooks '.ignore' file, either
in the main '.githooks' folder, or in the Git event specific one.

git hooks ignore [pattern...]
git hooks ignore [trigger] [pattern...]

	Note, that it may be required to surround the individual pattern
	parameters with single quotes to avoid expanding or splitting them.
	The 'trigger' parameter should be the name of the Git event if given.
	This command needs to be run at the root of a repository.`,
	Run: runIgnore,
}

func runIgnore(cmd *cobra.Command, args []string) {

}

func init() { // nolint: gochecknoinits
	rootCmd.AddCommand(ignoreCmd)
}
