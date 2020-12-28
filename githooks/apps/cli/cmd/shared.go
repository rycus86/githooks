package cmd

import (
	"github.com/spf13/cobra"
)

// sharedCmd represents the shared command.
var sharedCmd = &cobra.Command{
	Use:   "shared",
	Short: "Manages the shared hook repositories.",
	Long: `
Manages the shared hook repositories set either in the '.githooks.shared'
file locally in the repository or in the local or global
Git configuration 'githooks.shared'.

git hooks shared [add|remove] [--shared|--local|--global] <git-url>
git hooks shared clear [--shared|--local|--global|--all]
git hooks shared purge
git hooks shared list [--shared|--local|--global|--all]
git hooks shared [update|pull]

	Manages the shared hook repositories set either in the '.githooks.shared' file locally in the repository or
	in the local or global Git configuration 'githooks.shared'.
	The 'add' or 'remove' subcommands adds or removes an item, given as 'git-url' from the list.
	If '--local|--global' is given, then the 'githooks.shared' local/global Git configuration
	is modified, or if the '--shared' option (default) is set, the '.githooks/.shared'
	file is modified in the local repository.
	The 'clear' subcommand deletes every item on either the global or the local list,
	or both when the '--all' option is given.
	The 'purge' subcommand deletes the shared hook repositories already pulled locally.
	The 'list' subcommand list the shared, local, global or all (default) shared hooks repositories.
	The 'update' or 'pull' subcommands update all the shared repositories, either by
	running 'git pull' on existing ones or 'git clone' on new ones.`,
	Run: runShared,
}

func runShared(cmd *cobra.Command, args []string) {

}

func init() { // nolint: gochecknoinits
	rootCmd.AddCommand(sharedCmd)
}
