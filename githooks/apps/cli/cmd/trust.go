package cmd

import (
	"os"
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"
	"rycus86/githooks/hooks"
	strs "rycus86/githooks/strings"

	"github.com/spf13/cobra"
)

type TrustOption = int

const (
	TrustAdd    TrustOption = 0
	TrustRevoke TrustOption = 1
	TrustForget TrustOption = 2
	TrustDelete TrustOption = 3
)

// trustCmd represents the trust command.
var trustCmd = &cobra.Command{
	Use:   "trust",
	Short: "Manages settings related to trusted repositories.",
	Long: `
Sets up, or reverts the trusted setting for the local repository.

When called without arguments, it marks the local repository as trusted.

The 'revoke' argument resets the already accepted trust setting,
and the 'delete' argument also deletes the trusted marker.

The 'forget' option unsets the trust setting, asking for accepting
it again next time, if the repository is marked as trusted.`,
	Run: func(cmd *cobra.Command, args []string) {
		runTrust(TrustAdd)
	}}

var trustRevokeCmd = &cobra.Command{
	Use:   "revoke",
	Short: `Revoke trust settings.`,
	Run: func(cmd *cobra.Command, args []string) {
		runTrust(TrustRevoke)
	}}

var trustForgetCmd = &cobra.Command{
	Use:   "forget",
	Short: `Forget trust settings.`,
	Run: func(cmd *cobra.Command, args []string) {
		runTrust(TrustForget)
	}}

var trustDeleteCmd = &cobra.Command{
	Use:   "delete",
	Short: `Delete trust settings.`,
	Run: func(cmd *cobra.Command, args []string) {
		runTrust(TrustDelete)
	}}

func runTrust(opt TrustOption) {

	repoRoot := assertRepoRoot(&settings)
	file := hooks.GetTrustFile(repoRoot)

	switch opt {
	case TrustAdd:
		err := cm.TouchFile(file, true)
		log.AssertNoErrorPanicF(err, "Could not touch trust marker '%s'.", file)
		log.Info("The trust marker is added to the repository.")

		err = settings.GitX.SetConfig(hooks.GitCK_TrustAll, true, git.LocalScope)
		log.AssertNoErrorPanicF(err, "Could set trust settings.", hooks.GitCK_TrustAll)
		log.Info("The current repository is now trusted.")

		if !settings.GitX.IsBareRepo() {
			log.Info("Do not forget to commit and push it!")
		}
	case TrustForget:
		trust := settings.GitX.GetConfig(hooks.GitCK_TrustAll, git.LocalScope)
		if strs.IsEmpty(trust) {
			log.Info("The current repository does not have trust settings.")
		} else {
			err := settings.GitX.UnsetConfig(hooks.GitCK_TrustAll, git.LocalScope)
			log.AssertNoErrorPanicF(err, "Could not unset trust settings.", hooks.GitCK_TrustAll)
		}

		log.Info("The current repository is no longer trusted.")

	case TrustRevoke:
		fallthrough
	case TrustDelete:
		err := settings.GitX.SetConfig(hooks.GitCK_TrustAll, false, git.LocalScope)
		log.AssertNoErrorPanicF(err, "Could not set trust settings.", hooks.GitCK_TrustAll)
		log.Info("The current repository is no longer trusted.")
	}

	if opt == TrustDelete {
		err := os.RemoveAll(file)
		log.AssertNoErrorPanicF(err, "Could not remove trust marker '%s'.", file)

		log.Info("The trust marker is removed from the repository.")

		if !settings.GitX.IsBareRepo() {
			log.Info("Do not forget to commit and push it!")
		}
	}
}

func init() { // nolint: gochecknoinits
	trustCmd.AddCommand(setCommandDefaults(trustRevokeCmd))
	trustCmd.AddCommand(setCommandDefaults(trustForgetCmd))
	trustCmd.AddCommand(setCommandDefaults(trustDeleteCmd))

	rootCmd.AddCommand(setCommandDefaults(trustCmd))
}
