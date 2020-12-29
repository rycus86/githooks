package cmd

import (
	"os"
	"path"
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

	githooksRoot, err := settings.GitX.GetGithooksRoot()
	log.AssertNoErrorPanicF(err,
		"Current working directory '%s' is neither inside a worktree\n"+
			"nor inside a bare repository.",
		settings.Cwd)

	if opt == TrustAdd {
		file := hooks.GetTrustFile(githooksRoot)
		err := os.MkdirAll(path.Dir(githooksRoot), cm.DefaultFileModeDirectory)
		log.AssertNoErrorPanicF(err, "Could not create directory for '%s'.", file)
	}
}

func init() { // nolint: gochecknoinits
	trustCmd.AddCommand(SetCommandDefaults(trustRevokeCmd))
	trustCmd.AddCommand(SetCommandDefaults(trustForgetCmd))
	trustCmd.AddCommand(SetCommandDefaults(trustDeleteCmd))

	rootCmd.AddCommand(trustCmd)
}
