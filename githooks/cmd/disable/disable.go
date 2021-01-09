package disable

import (
	ccm "rycus86/githooks/cmd/common"
	"rycus86/githooks/git"
	"rycus86/githooks/hooks"

	"github.com/spf13/cobra"
)

type disableOptions struct {
	Reset bool
}

func RunDisable(ctx *ccm.CmdContext, reset bool, onlyPrint bool) {

	ccm.AssertRepoRoot(ctx)

	if onlyPrint {
		conf := ctx.GitX.GetConfig(hooks.GitCK_Disable, git.LocalScope)
		if conf == "true" {
			ctx.Log.InfoF("Githooks is disabled in the current repository.")
		} else {
			ctx.Log.InfoF("Githooks is not disabled in the current repository.")
		}

		return
	}

	if reset {
		err := ctx.GitX.UnsetConfig(hooks.GitCK_Disable, git.LocalScope)
		ctx.Log.AssertNoErrorPanic(err, "Could not unset Git config '%s'.", hooks.GitCK_Disable)
		ctx.Log.InfoF("Enabled Githooks in the current repository.")

	} else {
		err := ctx.GitX.SetConfig(hooks.GitCK_Disable, true, git.LocalScope)
		ctx.Log.AssertNoErrorPanic(err, "Could not set Git config '%s'.", hooks.GitCK_Disable)
		ctx.Log.InfoF("Disabled Githooks in the current repository.")
	}
}

func NewCmd(ctx *ccm.CmdContext) *cobra.Command {

	var disableOpts disableOptions

	disableCmd := &cobra.Command{
		Use:   "disable [flags]",
		Short: "Disables Githooks in the current repository.",
		Long: `Disables running any Githooks in the current repository.

LFS hooks and replaced previous hooks are still executed.`,
		PreRun: ccm.PanicIfAnyArgs(ctx.Log),
		Run: func(cmd *cobra.Command, args []string) {
			RunDisable(ctx, disableOpts.Reset, false)
		}}

	disableCmd.Flags().BoolVar(&disableOpts.Reset, "reset", false,
		`Resets the disable setting and enables running
hooks by Githooks again.`)

	return ccm.SetCommandDefaults(ctx.Log, disableCmd)
}
