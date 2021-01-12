package install

import (
	inst "rycus86/githooks/apps/install"
	ccm "rycus86/githooks/cmd/common"
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"
	"rycus86/githooks/hooks"

	"github.com/spf13/cobra"
)

func runInstallIntoRepo(ctx *ccm.CmdContext, nonInteractive bool) {
	_, gitDir, _ := ccm.AssertRepoRoot(ctx)

	// Check if useCoreHooksPath or core.hooksPath is set
	// and if so error out.
	value, exists := ctx.GitX.LookupConfig(git.GitCK_CoreHooksPath, git.Traverse)
	ctx.Log.PanicIfF(exists, "You are using already '%s' = '%s'\n"+
		"Installing Githooks run-wrappers into '%s'\n"+
		"has no effect.",
		git.GitCK_CoreHooksPath, value, gitDir)

	value, exists = ctx.GitX.LookupConfig(hooks.GitCK_UseCoreHooksPath, git.GlobalScope)
	ctx.Log.PanicIfF(exists && value == "true", "It appears you are using Githooks in 'core.hooksPath' mode\n"+
		"('%s' = '%s'). Installing Githooks run-wrappers into '%s'\n"+
		"may have no effect.",
		hooks.GitCK_UseCoreHooksPath, value, gitDir)

	uiSettings := inst.UISettings{PromptCtx: ctx.PromptCtx}
	inst.InstallIntoRepo(ctx.Log, gitDir, nonInteractive, false, &uiSettings)
}

func runUninstallFromRepo(ctx *ccm.CmdContext, nonInteractive bool) {
	_, gitDir, _ := ccm.AssertRepoRoot(ctx)

	// Read registered file if existing.
	var registeredGitDirs hooks.RegisterRepos
	err := registeredGitDirs.Load(ctx.InstallDir, true, true)
	ctx.Log.AssertNoErrorPanicF(err, "Could not load register file in '%s'.",
		ctx.InstallDir)

	lfsIsAvailable := git.IsLFSAvailable()
	if inst.UninstallFromRepo(ctx.Log, gitDir, lfsIsAvailable, false) {

		registeredGitDirs.Remove(gitDir)
		err := registeredGitDirs.Store(ctx.InstallDir)
		ctx.Log.AssertNoErrorPanicF(err, "Could not store register file in '%s'.",
			ctx.InstallDir)
	}
}

func runUninstall(ctx *ccm.CmdContext, nonInteractive bool, global bool) {
	exec := hooks.GetUninstallerExecutable(ctx.InstallDir)

	if !global {
		runUninstallFromRepo(ctx, nonInteractive)

		return
	}

	var args []string
	if nonInteractive {
		args = append(args, "--non-interactive")
	}

	err := cm.RunExecutable(
		&cm.ExecContext{},
		&cm.Executable{Path: exec},
		cm.UseStreams(nil, ctx.Log.GetInfoWriter(), ctx.Log.GetInfoWriter()), args...)

	ctx.Log.AssertNoErrorPanic(err, "Uninstaller failed.")
}

func runInstall(ctx *ccm.CmdContext, nonInteractive bool, global bool) {

	exec := hooks.GetInstallerExecutable(ctx.InstallDir)

	if !global {
		runInstallIntoRepo(ctx, nonInteractive)

		return
	}

	var args []string
	if nonInteractive {
		args = append(args, "--non-interactive")
	}

	err := cm.RunExecutable(
		&cm.ExecContext{},
		&cm.Executable{Path: exec},
		cm.UseStreams(nil, ctx.Log.GetInfoWriter(), ctx.Log.GetInfoWriter()), args...)

	ctx.Log.AssertNoErrorPanic(err, "Installer failed.")
}

func NewCmd(ctx *ccm.CmdContext) []*cobra.Command {

	global := false
	nonInteractive := false

	installCmd := &cobra.Command{
		Use:   "install",
		Short: "Installs Githooks locally or globally.",
		Long: `Installs the Githooks run wrappers into the current repository.

If the '--global' flag is given, it executes the installation
globally, including the hook templates for future repositories.`,
		Run: func(cmd *cobra.Command, args []string) {
			runInstall(ctx, nonInteractive, global)
		},
	}

	installCmd.Flags().BoolVar(&global, "global", false, "Execute the global installation.")
	installCmd.Flags().BoolVar(&nonInteractive, "non-interactive", false, "Uninstall non-interactively.")

	uninstallCmd := &cobra.Command{
		Use:   "uninstall",
		Short: "Uninstalls Githooks locally or globally.",
		Long: `Uninstalls the Githooks hooks from the current repository.

If the '--global' flag is given, it executes the uninstallation
globally, including the hook templates and all local repositories.`,
		Run: func(cmd *cobra.Command, args []string) {
			runUninstall(ctx, nonInteractive, global)
		},
	}

	uninstallCmd.Flags().BoolVar(&global, "global", false, "Execute the global uninstallation.")
	uninstallCmd.Flags().BoolVar(&nonInteractive, "non-interactive", false, "Uninstall non-interactively.")

	return []*cobra.Command{installCmd, uninstallCmd}
}
