package cmd

import (
	"github.com/spf13/cobra"
)

// installCmd represents the install command.
var installCmd = &cobra.Command{
	Use:   "install",
	Short: "Installs Githooks locally or globally.",
	Long: `
Installs the Githooks run wrappers into the current repository.

git hooks install [--global]

    If the '--global' flag is given, it executes the installation
    globally, including the hook templates for future repositories.`,
	Run: runInstall,
}

func runInstall(cmd *cobra.Command, args []string) {

}

// uninstallCmd represents the uninstall command.
var uninstallCmd = &cobra.Command{
	Use:   "uninstall",
	Short: "Uninstalls Githooks locally or globally.",
	Long: `
Uninstalls the Githooks hooks from the current repository.

git hooks uninstall [--global]

    If the '--global' flag is given, it executes the uninstallation
    globally, including the hook templates and all local repositories.`,
	Run: runUninstall,
}

func runUninstall(cmd *cobra.Command, args []string) {

}

func init() { // nolint: gochecknoinits
	rootCmd.AddCommand(installCmd)
	rootCmd.AddCommand(uninstallCmd)
}
