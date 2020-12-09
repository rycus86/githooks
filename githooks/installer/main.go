package main

import (
	"io/ioutil"
	"os"
	"path"
	"path/filepath"
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"
	"rycus86/githooks/hooks"
	strs "rycus86/githooks/strings"
	"rycus86/githooks/updates"

	"github.com/mitchellh/go-homedir"
	"github.com/spf13/cobra"
)

// InstallSettings are the settings for the installer.
type InstallSettings struct {
	args Arguments

	installDir string
	cloneDir   string
}

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

	cobra.OnInitialize()
	rootCmd.SetOutput(&ProxyWriter{log: log})
	rootCmd.Version = "1.0.0"

	defineArguments(rootCmd, &args)
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

func loadInstallDir(args *Arguments) (installDir string) {

	setDefault := func() {
		usr, err := homedir.Dir()
		cm.AssertNoErrorPanic(err, "Could not get home directory.")
		usr = filepath.ToSlash(usr)
		installDir = path.Join(usr, hooks.HookDirName)
	}

	// First check if we already have
	// an install directory set (from --prefix)
	if strs.IsNotEmpty(args.installPrefix) {
		var err error
		args.installPrefix, err = cm.ReplaceTilde(filepath.ToSlash(args.installPrefix))
		log.AssertNoErrorFatal(err, "Could not replace '~' character in path.")
		installDir = path.Join(args.installPrefix, ".githooks")

	} else {
		installDir = hooks.GetInstallDir()
		if !cm.IsDirectory(installDir) {
			log.WarnF("Install directors '%s' does not exist."+
				"Setting to default '~/.githooks'.", installDir)
			installDir = ""
		}
	}

	if strs.IsEmpty(installDir) {
		setDefault()
	}

	return
}

func setInstallDirAndRunner(installDir string) {
	runner := hooks.GetRunnerExecutable(installDir)
	log.AssertNoErrorFatal(hooks.SetInstallDir(installDir),
		"Could not set install dir '%s'", installDir)
	log.AssertNoErrorFatal(hooks.SetRunnerExecutable(runner),
		"Could not set runner executable '%s'", runner)
}

func buildFromSource(settings *InstallSettings, tempDir string, status updates.ReleaseStatus) {

	// Checkout release branch into temporary directory
	git.Clone(tempDir, settings.cloneDir, status.RemoteBranch, 1)

	// Build the binaries.
}

func downloadBinaries(settings *InstallSettings, tempDir string, status updates.ReleaseStatus) {

}

func prepareDispatch(settings *InstallSettings) {

	var status updates.ReleaseStatus
	var err error

	if args.internalAutoUpdate {

		status, err = updates.GetStatus(settings.cloneDir, true)

		log.AssertNoErrorFatal(err,
			"Could not get status of release clone '%s'",
			settings.cloneDir)

	} else {

		status, err = updates.FetchUpdates(
			settings.cloneDir,
			settings.args.cloneURL,
			settings.args.cloneBranch,
			true, updates.RecloneOnWrongRemote)

		log.AssertNoErrorFatal(err,
			"Could not assert release clone '%s' existing",
			settings.cloneDir)

	}

	tempDir, err := ioutil.TempDir(os.TempDir(), "githooks-update")
	log.AssertNoErrorFatal(err, "Can not create temporary update dir in '%s'", os.TempDir())
	defer os.RemoveAll(tempDir)

	updateSettings := updates.GetSettings()

	if updateSettings.DoBuildFromSource {
		buildFromSource(settings, tempDir, status)
	} else {
		downloadBinaries(settings, tempDir, status)
	}

	// Run installer binary

}

func runUpdate() {

}

func runInstall(cmd *cobra.Command, auxArgs []string) {
	parseEnv(&args)
	validateArgs(&args)

	settings := InstallSettings{}
	settings.args = args
	settings.installDir = loadInstallDir(&args)

	if !args.dryRun {
		setInstallDirAndRunner(settings.installDir)
	}

	if !args.internalPostUpdate {
		prepareDispatch(&settings)
	}

	runUpdate()
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
