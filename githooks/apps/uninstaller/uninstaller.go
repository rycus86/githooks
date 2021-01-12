//go:generate go run -mod=vendor ../../tools/embed-files.go
package main

import (
	"io/ioutil"
	"os"
	"path/filepath"
	"runtime"
	"rycus86/githooks/apps/install"
	"rycus86/githooks/build"
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"
	"rycus86/githooks/hooks"
	"rycus86/githooks/prompt"
	strs "rycus86/githooks/strings"
	"strings"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

var log cm.ILogContext
var logStats cm.ILogStats
var logN cm.ILogContext //nolint: unused // Acopy of `log` with no stats tracking.
var args = Arguments{}

// rootCmd represents the base command when called without any subcommands.
var rootCmd = &cobra.Command{
	Use:   "uninstaller",
	Short: "Githooks uninstaller application",
	Long: "Githooks uninstaller application\n" +
		"See further information at https://github.com/rycus86/githooks/blob/master/README.md",
	Run: runUninstall}

// Run adds all child commands to the root command and sets flags appropriately.
// This is called by main.main(). It only needs to happen once to the rootCmd.
func Run() {
	cobra.OnInitialize(initArgs)

	rootCmd.SetOut(cm.ToInfoWriter(log))
	rootCmd.SetErr(cm.ToErrorWriter(log))
	rootCmd.Version = build.BuildVersion

	defineArguments(rootCmd)

	cm.AssertNoErrorPanic(rootCmd.Execute())
}

func initArgs() {

	config := viper.GetString("config")
	if strs.IsNotEmpty(config) {
		viper.SetConfigFile(config)
		err := viper.ReadInConfig()
		log.AssertNoErrorPanicF(err, "Could not read config file '%s'.", config)
	}

	err := viper.Unmarshal(&args)
	log.AssertNoErrorPanicF(err, "Could not unmarshal parameters.")
}

func writeArgs(file string, args *Arguments) {
	err := cm.StoreJSON(file, args)
	log.AssertNoErrorPanicF(err, "Could not write arguments to '%s'.", file)
}

func defineArguments(rootCmd *cobra.Command) {
	// Internal commands
	rootCmd.PersistentFlags().String("config", "",
		"JSON config according to the 'Arguments' struct.")
	cm.AssertNoErrorPanic(rootCmd.MarkPersistentFlagDirname("config"))
	cm.AssertNoErrorPanic(rootCmd.PersistentFlags().MarkHidden("config"))

	// User commands
	rootCmd.PersistentFlags().Bool(
		"non-interactive", false,
		"Run the uninstallation non-interactively\n"+
			"without showing prompts.")

	rootCmd.Args = cobra.NoArgs

	cm.AssertNoErrorPanic(
		viper.BindPFlag("config", rootCmd.PersistentFlags().Lookup("config")))
	cm.AssertNoErrorPanic(
		viper.BindPFlag("nonInteractive", rootCmd.PersistentFlags().Lookup("non-interactive")))

	setupMockFlags(rootCmd)
}

func setMainVariables(args *Arguments) (Settings, UISettings) {

	var promptCtx prompt.IContext
	var err error

	cwd, err := os.Getwd()
	log.AssertNoErrorPanic(err, "Could not get current working directory.")

	if !args.NonInteractive {
		promptCtx, err = prompt.CreateContext(log, &cm.ExecContext{}, nil, false, args.UseStdin)
		log.AssertNoErrorF(err, "Prompt setup failed -> using fallback.")
	}

	installDir := install.LoadInstallDir(log)

	// Safety check.
	log.PanicIfF(!strings.Contains(installDir, ".githooks"),
		"Uninstall path at '%s' needs to contain '.githooks'.")

	// Remove temporary directory if existing
	tempDir, err := hooks.CleanTemporaryDir(installDir)
	log.AssertNoErrorPanicF(err,
		"Could not clean temporary directory in '%s'", installDir)

	return Settings{
			Cwd:                cwd,
			InstallDir:         installDir,
			CloneDir:           hooks.GetReleaseCloneDir(installDir),
			TempDir:            tempDir,
			UninstalledGitDirs: make(UninstallSet, 10),
			LFSAvailable:       git.IsLFSAvailable()},
		UISettings{PromptCtx: promptCtx}
}

func prepareDispatch(settings *Settings, args *Arguments) bool {

	uninstaller := hooks.GetUninstallerExecutable(settings.InstallDir)
	if !cm.IsFile(uninstaller) {
		log.WarnF("There is no existing Githooks uninstaller present\n"+
			"in install dir '%s'.\n"+
			"Your installation is corrupt.\n"+
			"We will continue to uninstall agnostically with this installer.",
			settings.InstallDir)

		return false
	}

	// Set variables for further uninstall procedure.
	args.InternalPostDispatch = true

	runUninstaller(uninstaller, args)

	return true
}

func runUninstaller(uninstaller string, args *Arguments) {

	log.Info("Dispatching to uninstaller ...")
	log.PanicIfF(!cm.IsFile(uninstaller), "Uninstaller '%s' is not existing.", uninstaller)

	file, err := ioutil.TempFile("", "*uninstall-config.json")
	log.AssertNoErrorPanicF(err, "Could not create temporary file in '%s'.")
	defer os.Remove(file.Name())

	// Write the config to
	// make the uninstaller gettings all settings
	writeArgs(file.Name(), args)

	// Run the uninstaller binary
	err = cm.RunExecutable(
		&cm.ExecContext{},
		&cm.Executable{Path: uninstaller},
		cm.UseStreams(os.Stdin, log.GetInfoWriter(), log.GetInfoWriter()),
		"--config", file.Name())

	log.AssertNoErrorPanic(err, "Running uninstaller failed.")
}

func thankYou() {
	log.InfoF(
		"All done! Enjoy!\n"+
			"If you ever want to reinstall the hooks, just follow\n"+
			"the install instructions at '%s'.", hooks.GithooksWebpage)
}

func uninstallFromExistingRepos(
	lfsAvailable bool,
	tempDir string,
	nonInteractive bool,
	uninstalledRepos UninstallSet,
	registeredRepos *hooks.RegisterRepos,
	uiSettings *UISettings) {

	// Show prompt and run callback.
	install.PromptExistingRepos(
		log,
		nonInteractive,
		true,
		uiSettings.PromptCtx,
		func(gitDir string) {

			if install.UninstallFromRepo(log, gitDir, lfsAvailable, true) {

				registeredRepos.Remove(gitDir)
				uninstalledRepos.Insert(gitDir)
			}
		})
}

func uninstallFromRegisteredRepos(
	lfsAvailable bool,
	tempDir string,
	nonInteractive bool,
	uninstalledRepos UninstallSet,
	registeredRepos *hooks.RegisterRepos,
	uiSettings *UISettings) {

	if len(registeredRepos.GitDirs) == 0 {
		return
	}

	dirsWithNoUninstalls := strs.Filter(registeredRepos.GitDirs,
		func(s string) bool {
			return !uninstalledRepos.Exists(s)
		})

	// Show prompt and run callback.
	install.PromptRegisteredRepos(
		log,
		dirsWithNoUninstalls,
		nonInteractive,
		true,
		uiSettings.PromptCtx,
		func(gitDir string) {
			if install.UninstallFromRepo(log, gitDir, lfsAvailable, true) {

				registeredRepos.Remove(gitDir)
				uninstalledRepos.Insert(gitDir)
			}
		})
}

func cleanTemplateDir() {
	installUsesCoreHooksPath := git.Ctx().GetConfig(hooks.GitCK_UseCoreHooksPath, git.GlobalScope)

	hookTemplateDir, err := install.FindHookTemplateDir(installUsesCoreHooksPath == "true")
	log.AssertNoErrorF(err, "Error while determining default hook template directory.")

	if strs.IsEmpty(hookTemplateDir) {
		log.ErrorF(
			"Git hook templates directory not found.\n" +
				"Installation is corrupt!")
	} else {
		err = hooks.UninstallRunWrappers(hookTemplateDir, hooks.ManagedHookNames)
		log.AssertNoErrorF(err, "Could not uninstall Githooks run wrappers in\n'%s'.", hookTemplateDir)
	}
}

func cleanSharedClones(installDir string) {
	sharedDir := hooks.GetSharedDir(installDir)

	if cm.IsDirectory(sharedDir) {
		err := os.RemoveAll(sharedDir)
		log.AssertNoErrorF(err,
			"Could not delete shared directory '%s'.", sharedDir)
	}
}

func deleteDir(dir string, tempDir string) {
	if runtime.GOOS == "windows" {
		// On Windows we cannot move binaries which we execute at the moment.
		// We move everything to a new random folder inside tempDir
		// and notify the user.

		tmp := cm.GetTempPath(tempDir, "old-binaries")
		err := os.Rename(dir, tmp)
		log.AssertNoErrorF(err, "Could not move dir\n'%s' to '%s'.", dir, tmp)

	} else {
		// On Unix system we can simply remove the binary dir,
		// even if we are running the installer
		err := os.RemoveAll(dir)
		log.AssertNoErrorF(err, "Could not delete dir '%s'.", dir)
	}
}

func cleanBinaries(
	installDir string,
	tempDir string) {

	binDir := hooks.GetBinaryDir(installDir)

	if cm.IsDirectory(binDir) {
		deleteDir(binDir, tempDir)
	}
}

func cleanReleaseClone(
	installDir string) {

	cloneDir := hooks.GetReleaseCloneDir(installDir)

	if cm.IsDirectory(cloneDir) {
		err := os.RemoveAll(cloneDir)
		log.AssertNoErrorF(err,
			"Could not delete release clone directory '%s'.", cloneDir)
	}
}

func cleanGitConfig() {
	gitx := git.Ctx()

	// Remove core.hooksPath if we are using it.
	pathForUseCoreHooksPath := gitx.GetConfig(hooks.GitCK_PathForUseCoreHooksPath, git.GlobalScope)
	coreHooksPath := gitx.GetConfig(git.GitCK_CoreHooksPath, git.GlobalScope)

	if coreHooksPath == pathForUseCoreHooksPath {
		err := gitx.UnsetConfig(git.GitCK_CoreHooksPath, git.GlobalScope)
		log.AssertNoError(err, "Could not unset global Git config 'core.hooksPath'.")
	}

	// Remove all global configs
	for _, k := range hooks.GetGlobalGitConfigKeys() {

		log.AssertNoErrorF(gitx.UnsetConfig(k, git.GlobalScope),
			"Could not unset global Git config '%s'.", k)
	}
}

func cleanRegister(installDir string) {

	registerFile := hooks.GetRegisterFile(installDir)

	if cm.IsFile(registerFile) {
		err := os.Remove(registerFile)
		log.AssertNoError(err,
			"Could not delete register file '%s'.", registerFile)
	}
}

func runUninstallSteps(
	settings *Settings,
	uiSettings *UISettings,
	args *Arguments) {

	// Read registered file if existing.
	// We ensured during load, that only existing Git directories are listed.
	err := settings.RegisteredGitDirs.Load(settings.InstallDir, true, true)
	log.AssertNoErrorPanicF(err, "Could not load register file in '%s'.",
		settings.InstallDir)

	log.InfoF("Running uninstall at version '%s' ...", build.BuildVersion)

	uninstallFromExistingRepos(
		settings.LFSAvailable,
		settings.TempDir,
		args.NonInteractive,
		settings.UninstalledGitDirs,
		&settings.RegisteredGitDirs,
		uiSettings)

	uninstallFromRegisteredRepos(
		settings.LFSAvailable,
		settings.TempDir,
		args.NonInteractive,
		settings.UninstalledGitDirs,
		&settings.RegisteredGitDirs,
		uiSettings)

	cleanTemplateDir()

	cleanSharedClones(settings.InstallDir)
	cleanReleaseClone(settings.InstallDir)
	cleanBinaries(settings.InstallDir, settings.TempDir)
	cleanRegister(settings.InstallDir)

	cleanGitConfig()

	if logStats.ErrorCount() == 0 {
		thankYou()
	} else {
		log.ErrorF("Tried my best at uninstalling, but\n"+
			" • %v errors\n"+
			" • %v warnings\n"+
			"occurred!", logStats.ErrorCount(), logStats.WarningCount())
	}
}

func runUninstall(cmd *cobra.Command, auxArgs []string) {

	log.DebugF("Arguments: %+v", args)

	settings, uiSettings := setMainVariables(&args)

	if !args.InternalPostDispatch {
		if isDispatched := prepareDispatch(&settings, &args); isDispatched {
			return
		}
	}

	runUninstallSteps(&settings, &uiSettings, &args)
}

func setupLog() {
	l, err := cm.CreateLogContext(cm.IsRunInDocker)
	cm.AssertOrPanic(err == nil, "Could not create log")

	l2 := cm.LogContext(*l)
	l2.DisableStats()
	log = l
	logStats = l
	logN = &l2
}

func main() {

	cwd, err := os.Getwd()
	cm.AssertNoErrorPanic(err, "Could not get current working dir.")
	cwd = filepath.ToSlash(cwd)

	setupLog()

	log.InfoF("Githooks Uninstaller [version: %s]", build.BuildVersion)

	exitCode := 0
	defer func() { os.Exit(exitCode) }()

	// Handle all panics and report the error
	defer func() {
		r := recover()
		if hooks.HandleCLIErrors(r, cwd, log) {
			exitCode = 1
		}
	}()

	Run()

	if logStats.ErrorCount() != 0 {
		exitCode = 1
	}

}
