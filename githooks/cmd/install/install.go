package install

import (
	ccm "rycus86/githooks/cmd/common"
	cm "rycus86/githooks/common"
	"rycus86/githooks/hooks"

	"github.com/spf13/cobra"
)

func runUninstall(ctx *ccm.CmdContext, global bool) {
	exec := hooks.GetUninstallerExecutable(ctx.InstallDir)
	var args []string

	if !global {
		args = append(args, "--single")
	}

	err := cm.RunExecutable(
		&cm.ExecContext{},
		&cm.Executable{Path: exec},
		cm.UseStreams(nil, ctx.Log.GetInfoWriter(), ctx.Log.GetInfoWriter()), args...)

	ctx.Log.AssertNoErrorPanic(err, "Uninstaller failed.")
}

func runInstall(ctx *ccm.CmdContext, global bool) {

	exec := hooks.GetInstallerExecutable(ctx.InstallDir)
	var args []string

	if !global {
		args = append(args, "--single")
	}

	err := cm.RunExecutable(
		&cm.ExecContext{},
		&cm.Executable{Path: exec},
		cm.UseStreams(nil, ctx.Log.GetInfoWriter(), ctx.Log.GetInfoWriter()), args...)

	ctx.Log.AssertNoErrorPanic(err, "Installer failed.")
}

func NewCmd(ctx *ccm.CmdContext) []*cobra.Command {

	global := false

	installCmd := &cobra.Command{
		Use:   "install",
		Short: "Installs Githooks locally or globally.",
		Long: `Installs the Githooks run wrappers into the current repository.

If the '--global' flag is given, it executes the installation
globally, including the hook templates for future repositories.`,
		Run: func(cmd *cobra.Command, args []string) {
			runInstall(ctx, global)
		},
	}

	installCmd.Flags().BoolVar(&global, "global", false, "Execute the global installation.")

	uninstallCmd := &cobra.Command{
		Use:   "uninstall",
		Short: "Uninstalls Githooks locally or globally.",
		Long: `Uninstalls the Githooks hooks from the current repository.

If the '--global' flag is given, it executes the uninstallation
globally, including the hook templates and all local repositories.`,
		Run: func(cmd *cobra.Command, args []string) { runUninstall(ctx, global) },
	}

	uninstallCmd.Flags().BoolVar(&global, "global", false, "Execute the global installation.")

	return []*cobra.Command{installCmd, uninstallCmd}
}
