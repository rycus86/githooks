package main

import (
	"os"
	"path/filepath"
	cm "rycus86/githooks/common"
	"rycus86/githooks/hooks"

	"github.com/spf13/cobra"
)

var log cm.ILogContext
var args = GetDefaultArgs()

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "githooks-installer",
	Short: "Githooks installer application",
	Long: "Githooks installer application\n" +
		"See further information at https://github.com/rycus86/githooks/blob/master/README.md",
	Run: runInstall}

// ProxyWriter is solely used for the cobra logging.
type ProxyWriter struct {
	log cm.ILogContext
}

func (p *ProxyWriter) Write(s []byte) (int, error) {
	return os.Stdout.Write([]byte(p.log.ColorInfo(string(s))))
}

// Execute adds all child commands to the root command and sets flags appropriately.
// This is called by main.main(). It only needs to happen once to the rootCmd.
func Execute() {
	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}

func init() {
	var err error
	log, err = cm.CreateLogContext(false)
	cm.AssertOrPanic(err == nil, "Could not create log")

	cobra.OnInitialize(initConfig)
	rootCmd.SetOutput(&ProxyWriter{log: log})
	rootCmd.Version = "1.0.0"

	defineArguments(rootCmd, &args)
}

// initConfig reads in config file and ENV variables if set.
func initConfig() {
}

func defineArguments(rootCmd *cobra.Command, args *Arguments) {
	// Internal commands
	rootCmd.PersistentFlags().BoolVar(&args.internalInstall,
		"internal-install", false, "Internal argument, do not use!")
	rootCmd.PersistentFlags().BoolVar(&args.internalAutoUpdate,
		"internal-auto-update", false, "Internal argument, do not use!")

	rootCmd.PersistentFlags().BoolVar(&args.internalPostUpdate,
		"internal-post-update", false, "Internal argument, do not use!")

	rootCmd.PersistentFlags().StringVar(&args.internalUpdatedFrom,
		"internal-updated-from", "", "Internal argument, do not use!")

	// User commands
	rootCmd.PersistentFlags().BoolVar(&args.dryRun,
		"dry-run", false, "Dry run the installation showing whats beeing done.")
	rootCmd.PersistentFlags().BoolVar(&args.nonInteractive,
		"non-interactive", false,
		"Run the installation non-interactively\n"+
			"without showing prompts.")

	rootCmd.PersistentFlags().BoolVar(&args.singleInstall,
		"single", false,
		"Install Githooks in the active repository only.\n"+
			"This does not mean it won't install necessary\n"+
			"files into the installation directory.")

	rootCmd.PersistentFlags().BoolVar(&args.nonInteractive,
		"skip-install-into-existing", false,
		"Skip installation into existing repositories\n"+
			"defined by a search path.")

	rootCmd.PersistentFlags().StringVar(&args.installPrefix,
		"prefix", "",
		"Githooks installation prefix such that\n"+
			"'<prefix>/.githooks' will be the installation directory.")

	rootCmd.PersistentFlags().StringVar(&args.templateDir,
		"template-dir", "",
		"The preferred template directory to use.")

	rootCmd.PersistentFlags().BoolVar(&args.onlyServerHooks,
		"only-server-hooks", false,
		"Only install and maintain server hooks.")

	rootCmd.PersistentFlags().BoolVar(&args.useCoreHooksPath,
		"use-core-hookspath", false,
		"If the install mode 'core.hooksPath' should be used.")

	rootCmd.PersistentFlags().StringVar(&args.cloneURL,
		"clone-url", "",
		"The clone url from which Githooks should clone\n"+
			"and install itself.")

	rootCmd.PersistentFlags().StringVar(&args.cloneBranch,
		"clone-branch", "",
		"The clone branch from which Githooks should\n"+
			"clone and install itself.")

	rootCmd.Args = cobra.NoArgs
}

func parseEnv(args *Arguments) {
	if _, exists := os.LookupEnv("GITHOOKS_INTERNAL_INSTALL"); exists {
		args.internalInstall = true
	}
	if _, exists := os.LookupEnv("GITHOOKS_INTERNAL_AUTOUPDATE"); exists {
		args.internalAutoUpdate = true
	}
	if _, exists := os.LookupEnv("GITHOOKS_INTERNAL_POSTUPDATE"); exists {
		args.internalPostUpdate = true
	}
	if sha, exists := os.LookupEnv("GITHOOKS_INTERNAL_UPDATED_FROM"); exists {
		args.internalUpdatedFrom = sha
	}
}

func validateArgs(args *Arguments) {
	log.FatalIfF(args.singleInstall && args.useCoreHooksPath,
		"Cannot use --single and --use-core-hookspath together. See `--help`.")
}

func runInstall(cmd *cobra.Command, auxArgs []string) {
	parseEnv(&args)
	validateArgs(&args)
}

func main() {

	cwd, err := os.Getwd()
	cm.AssertNoErrorPanic(err, "Could not get current working dir.")
	cwd = filepath.ToSlash(cwd)

	var exitCode int
	defer func() { os.Exit(exitCode) }()

	// Handle all panics and report the error
	defer func() {
		r := recover()
		if hooks.HandleCLIErrors(r, cwd, log) {
			exitCode = 1
		}
	}()

	Execute()
}
