package cmd

import (
	"github.com/spf13/cobra"
)

// trustCmd represents the trust command.
var trustCmd = &cobra.Command{
	Use:   "trust",
	Short: "Manages settings related to trusted repositories.",
	Long: `
Sets up, or reverts the trusted setting for the local repository.

git hooks trust
git hooks trust [revoke]
git hooks trust [delete]
git hooks trust [forget]

	When called without arguments, it marks the local repository as trusted.
	The 'revoke' argument resets the already accepted trust setting,
	and the 'delete' argument also deletes the trusted marker.
	The 'forget' option unsets the trust setting, asking for accepting
	it again next time, if the repository is marked as trusted.`,
	Run: runTrust,
}

func runTrust(cmd *cobra.Command, args []string) {

}

func init() { // nolint: gochecknoinits
	rootCmd.AddCommand(trustCmd)
}
