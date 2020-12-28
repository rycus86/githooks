package cmd

import (
	"github.com/spf13/cobra"
)

// readmeCmd represents the readme command.
var readmeCmd = &cobra.Command{
	Use:   "readme",
	Short: "Manages the Githooks README in the current repository.",
	Long: `
Adds or updates the Githooks README in the '.githooks' folder.

git hooks readme [add|update]

	If 'add' is used, it checks first if there is a README file already.
	With 'update', the file is always updated, creating it if necessary.
	This command needs to be run at the root of a repository.`,
	Run: runReadme,
}

func runReadme(cmd *cobra.Command, args []string) {

}

func init() { // nolint: gochecknoinits
	rootCmd.AddCommand(readmeCmd)
}
