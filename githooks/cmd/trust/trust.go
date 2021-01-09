package trust

import (
	"os"
	ccm "rycus86/githooks/cmd/common"
	cm "rycus86/githooks/common"
	"rycus86/githooks/hooks"

	"github.com/spf13/cobra"
)

type TrustOption = int

const (
	TrustAdd    TrustOption = 0
	TrustRevoke TrustOption = 1
	TrustForget TrustOption = 2
	TrustDelete TrustOption = 3
)

func runTrust(ctx *ccm.CmdContext, opt TrustOption) {

	repoRoot, _ := ccm.AssertRepoRoot(ctx)
	file := hooks.GetTrustMarkerFile(repoRoot)

	switch opt {
	case TrustAdd:
		err := cm.TouchFile(file, true)
		ctx.Log.AssertNoErrorPanicF(err, "Could not touch trust marker '%s'.", file)
		ctx.Log.Info("The trust marker is added to the repository.")

		err = hooks.SetTrustAllSetting(ctx.GitX, true, false)
		ctx.Log.AssertNoErrorPanic(err, "Could not set trust settings.")
		ctx.Log.Info("The current repository is now trusted.")

		if !ctx.GitX.IsBareRepo() {
			ctx.Log.Info("Do not forget to commit and push it!")
		}
	case TrustForget:
		_, isSet := hooks.GetTrustAllSetting(ctx.GitX)
		if !isSet {
			ctx.Log.Info("The current repository does not have trust settings.")
		} else {
			err := hooks.SetTrustAllSetting(ctx.GitX, false, true)
			ctx.Log.AssertNoErrorPanic(err, "Could not unset trust settings.")
		}

		ctx.Log.Info("The current repository is no longer trusted.")

	case TrustRevoke:
		fallthrough
	case TrustDelete:
		err := hooks.SetTrustAllSetting(ctx.GitX, false, false)
		ctx.Log.AssertNoErrorPanicF(err, "Could not set trust settings.")
		ctx.Log.Info("The current repository is no longer trusted.")
	}

	if opt == TrustDelete {
		err := os.RemoveAll(file)
		ctx.Log.AssertNoErrorPanicF(err, "Could not remove trust marker '%s'.", file)

		ctx.Log.Info("The trust marker is removed from the repository.")

		if !ctx.GitX.IsBareRepo() {
			ctx.Log.Info("Do not forget to commit and push it!")
		}
	}
}

func NewCmd(ctx *ccm.CmdContext) *cobra.Command {

	trustCmd := &cobra.Command{
		Use:   "trust",
		Short: "Manages settings related to trusted repositories.",
		Long: `Sets up, or reverts the trusted setting for the local repository.

When called without arguments, it marks the local repository as trusted.

The 'revoke' argument resets the already accepted trust setting,
and the 'delete' argument also deletes the trusted marker.

The 'forget' option unsets the trust setting, asking for accepting
it again next time, if the repository is marked as trusted.`,
		Run: func(cmd *cobra.Command, args []string) {
			runTrust(ctx, TrustAdd)
		}}

	trustRevokeCmd := &cobra.Command{
		Use:   "revoke",
		Short: `Revoke repository trust settings.`,
		Run: func(cmd *cobra.Command, args []string) {
			runTrust(ctx, TrustRevoke)
		}}

	trustForgetCmd := &cobra.Command{
		Use:   "forget",
		Short: `Forget repository trust settings.`,
		Run: func(cmd *cobra.Command, args []string) {
			runTrust(ctx, TrustForget)
		}}

	trustDeleteCmd := &cobra.Command{
		Use:   "delete",
		Short: `Delete repository trust settings.`,
		Run: func(cmd *cobra.Command, args []string) {
			runTrust(ctx, TrustDelete)
		}}

	trustCmd.AddCommand(
		ccm.SetCommandDefaults(ctx.Log, trustRevokeCmd),
		ccm.SetCommandDefaults(ctx.Log, trustForgetCmd),
		ccm.SetCommandDefaults(ctx.Log, trustDeleteCmd),
		ccm.SetCommandDefaults(ctx.Log, NewTrustHooksCmd(ctx)))

	return ccm.SetCommandDefaults(ctx.Log, trustCmd)
}
