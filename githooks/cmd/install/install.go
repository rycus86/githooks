package install

import (
	ccm "rycus86/githooks/cmd/common"

	"github.com/spf13/cobra"
)

func runUninstall(ctx *ccm.CmdContext) {

}

func runInstall(ctx *ccm.CmdContext) {

}

func NewCmd(ctx *ccm.CmdContext) []*cobra.Command {

	installCmd := &cobra.Command{
		Use:   "install",
		Short: "Installs Githooks locally or globally.",
		Long: `
Installs the Githooks run wrappers into the current repository.

git hooks install [--global]

    If the '--global' flag is given, it executes the installation
    globally, including the hook templates for future repositories.`,
		Run: func(cmd *cobra.Command, args []string) { runInstall(ctx) },
	}

	uninstallCmd := &cobra.Command{
		Use:   "uninstall",
		Short: "Uninstalls Githooks locally or globally.",
		Long: `
Uninstalls the Githooks hooks from the current repository.

git hooks uninstall [--global]

    If the '--global' flag is given, it executes the uninstallation
    globally, including the hook templates and all local repositories.`,
		Run: func(cmd *cobra.Command, args []string) { runUninstall(ctx) },
	}

	return []*cobra.Command{installCmd, uninstallCmd}
}
