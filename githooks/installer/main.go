package main

import (
	"io/ioutil"
	"os"
	"path"
	"path/filepath"
	"rycus86/githooks/build"
	"rycus86/githooks/builder"
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"
	"rycus86/githooks/hooks"
	strs "rycus86/githooks/strings"
	"rycus86/githooks/updates"
	"strings"

	"github.com/mitchellh/go-homedir"
	"github.com/spf13/cobra"
)

// InstallSettings are the settings for the installer.
type InstallSettings struct {
	args *Arguments

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
	rootCmd.PersistentFlags().BoolVar(&args.internalAutoUpdate,
		"internal-auto-update", false, "Internal argument, do not use!")

	rootCmd.PersistentFlags().BoolVar(&args.internalPostUpdate,
		"internal-post-update", false, "Internal argument, do not use!")

	rootCmd.PersistentFlags().StringVar(&args.internalUpdateTo,
		"internal-update-to", "", "Internal argument, do not use!")

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

	rootCmd.PersistentFlags().BoolVar(&args.buildFromSource,
		"build-from-source", false,
		"If the binaries are built from source instead of\n"+
			"downloaded from the deploy url.")

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
	if sha, exists := os.LookupEnv("GITHOOKS_INTERNAL_UPDATE_TO"); exists {
		args.internalUpdateTo = sha
	}
}

func validateArgs(args *Arguments) {
	log.FatalIfF(args.singleInstall && args.useCoreHooksPath,
		"Cannot use --single and --use-core-hookspath together. See `--help`.")
}

func setMainVariables(args *Arguments) InstallSettings {

	var installDir string

	getDefault := func() string {
		usr, err := homedir.Dir()
		cm.AssertNoErrorPanic(err, "Could not get home directory.")
		usr = filepath.ToSlash(usr)
		return path.Join(usr, hooks.HookDirName)
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
			log.WarnF("Install directory '%s' does not exist.\n"+
				"Setting to default '~/.githooks'.", installDir)
			installDir = ""
		}
	}

	if strs.IsEmpty(installDir) {
		installDir = getDefault()
	}

	return InstallSettings{
		args:       args,
		installDir: installDir,
		cloneDir:   hooks.GetReleaseCloneDir(installDir)}
}

func setInstallDirAndRunner(installDir string) {
	runner := hooks.GetRunnerExecutable(installDir)
	log.AssertNoErrorFatal(hooks.SetInstallDir(installDir),
		"Could not set install dir '%s'", installDir)
	log.AssertNoErrorFatal(hooks.SetRunnerExecutable(runner),
		"Could not set runner executable '%s'", runner)
}

func buildFromSource(
	settings *InstallSettings, tempDir string,
	url string, branch string, commitSHA string) updates.Binaries {

	log.Info("Building binaries from source ...")

	// Clone another copy of the release clone into temporary directory
	log.InfoF("Clone to temporary build directory '%s'", tempDir)
	err := git.Clone(tempDir, url, branch, -1)
	log.AssertNoErrorFatalF(err, "Could not clone release branch into '%s'.", tempDir)

	// Checkout the remote commit sha
	log.InfoF("Checkout out commit '%s'", commitSHA[0:6])
	gitx := git.CtxC(tempDir)
	err = gitx.Check("checkout",
		"-b", "update-to-"+commitSHA[0:6],
		commitSHA)

	log.AssertNoErrorFatalF(err,
		"Could not checkout update commit '%s' in '%s'.",
		commitSHA, tempDir)

	tag, _ := gitx.Get("describe", "--tags", "--abbrev=6")
	log.InfoF("Building binaries at '%s'", tag)

	// Build the binaries.
	binPath, err := builder.Build(tempDir)
	log.AssertNoErrorFatalF(err, "Could not build release branch in '%s'.", tempDir)

	bins, err := cm.GetAllFiles(binPath)
	log.AssertNoErrorFatalF(err, "Could not get files in path '%s'.", binPath)

	binaries := updates.Binaries{}
	strs.Map(bins, func(s string) string {
		if cm.IsExecutable(s) {
			if strings.Contains(s, "installer") {
				binaries.Installer = s
			} else {
				binaries.Others = append(binaries.Others, s)
			}
			binaries.All = append(binaries.All, s)
		}
		return s
	})

	log.InfoF(
		"Successfully built %v binaries:\n - %s",
		len(binaries.All),
		strings.Join(
			strs.Map(binaries.All,
				func(s string) string { return path.Base(s) }),
			"\n - "))

	log.FatalIf(
		len(binaries.All) == 0 ||
			strs.IsEmpty(binaries.Installer),
		"No binaries found in '%s'", binPath)

	return binaries
}

func downloadBinaries(settings *InstallSettings, tempDir string, status updates.ReleaseStatus) {
	log.Fatal("Not implemented")
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

		log.AssertNoErrorFatalF(err,
			"Could not assert release clone '%s' existing",
			settings.cloneDir)
	}

	tempDir, err := ioutil.TempDir(os.TempDir(), "githooks-update")
	log.AssertNoErrorFatal(err, "Can not create temporary update dir in '%s'", os.TempDir())
	defer os.RemoveAll(tempDir)

	updateSettings := updates.GetSettings()

	binaries := updates.Binaries{}
	if settings.args.buildFromSource || updateSettings.DoBuildFromSource {
		binaries = buildFromSource(
			settings, tempDir,
			status.RemoteURL, status.Branch, status.RemoteCommitSHA)
	} else {
		downloadBinaries(settings, tempDir, status)
	}

	updateTo := ""
	if status.LocalCommitSHA != status.RemoteCommitSHA {
		updateTo = status.RemoteCommitSHA
	}

	// Run the installer binary
	err = cm.RunExecutable(
		&cm.ExecContext{},
		&cm.Executable{Path: binaries.Installer},
		true,
		"--internal-post-update",
		strs.Fmt("--internal-update-to=%s", updateTo))

	log.AssertNoErrorFatal(err, "Running installer failed.")
}

func runUpdate() {
	log.InfoF("Running update to version '%s' ...", build.BuildVersion)
}

func runInstall(cmd *cobra.Command, auxArgs []string) {

	log.InfoF("Installer [version: %s]", build.BuildVersion)

	parseEnv(&args)
	validateArgs(&args)

	settings := setMainVariables(&args)

	if !args.dryRun {
		setInstallDirAndRunner(settings.installDir)
	}

	if !args.internalPostUpdate {
		prepareDispatch(&settings)
	} else {
		runUpdate()
	}

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
