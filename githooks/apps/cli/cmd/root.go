package cmd

import (
	"os"
	"rycus86/githooks/apps/install"
	"rycus86/githooks/build"
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"
	"rycus86/githooks/hooks"
	"rycus86/githooks/prompt"

	"github.com/spf13/cobra"
)

var log cm.ILogContext
var settings Settings

// rootCmd represents the base command when called without any subcommands.
var rootCmd = &cobra.Command{
	Use:   "git hooks", // Contains a en-space (utf-8: U+2002) to make it work...
	Short: "Githooks CLI application",
	Long:  "See further information at https://github.com/rycus86/githooks/blob/master/README.md",
	Run:   panicWrongArgs}

func setMainVariables() Settings {

	var promptCtx prompt.IContext
	var err error

	cwd, err := os.Getwd()
	log.AssertNoErrorPanic(err, "Could not get current working directory.")

	promptCtx, err = prompt.CreateContext(log, &cm.ExecContext{}, nil, false, false)
	log.AssertNoErrorF(err, "Prompt setup failed -> using fallback.")

	installDir := install.LoadInstallDir(log)

	return Settings{
		Cwd:        cwd,
		GitX:       git.CtxC(cwd),
		InstallDir: installDir,
		CloneDir:   hooks.GetReleaseCloneDir(installDir),
		PromptCtx:  promptCtx}
}

func Run(l cm.ILogContext) {
	log = l // Set the global log

	fmt := log.GetInfoFormatter(false)
	title := fmt("Githooks CLI [version: %s]", build.BuildVersion)
	firstPrefix := " ▶ "
	InitTemplates(title, firstPrefix, log.GetIndent())

	SetCommandDefaults(rootCmd)
	rootCmd.SetOut(cm.ToInfoWriter(log))
	rootCmd.SetErr(cm.ToErrorWriter(log))
	rootCmd.Version = build.BuildVersion

	ModifyTemplate(rootCmd, log.GetIndent())

	settings = setMainVariables()

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
