package cmd

import (
	"os"
	"rycus86/githooks/build"
	cm "rycus86/githooks/common"

	"github.com/spf13/cobra"
)

var log cm.ILogContext

// rootCmd represents the base command when called without any subcommands.
var rootCmd = &cobra.Command{
	Use:   "git hooks", // Contains a en-space (utf-8: U+2002) to make it work...
	Short: "Githooks CLI application",
	Long:  "See further information at https://github.com/rycus86/githooks/blob/master/README.md"}

func Run(l cm.ILogContext) {
	log = l // Set the global log

	title := log.GetInfoFormatter()("Githooks CLI [version: %s]", build.BuildVersion)
	InitTemplates(title, log.GetIndent())

	rootCmd.SetOut(cm.ToInfoWriter(log))
	rootCmd.SetErr(cm.ToErrorWriter(log))
	rootCmd.Version = build.BuildVersion

	ModifyTemplate(rootCmd, log.GetIndent())

	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}

// Run adds all child commands to the root command and sets flags appropriately.
// This is called by main.main(). It only needs to happen once to the rootCmd.
func init() { //nolint: gochecknoinits
	cobra.OnInitialize(initArgs)
}

func initArgs() {
	// Initialize from config , ENV -> viper
	// not yet needed...
}
