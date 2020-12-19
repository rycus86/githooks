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
	"rycus86/githooks/prompt"
	strs "rycus86/githooks/strings"
	"rycus86/githooks/updates"
	"strings"

	"github.com/mitchellh/go-homedir"
	"github.com/spf13/cobra"
	"github.com/spf13/pflag"
	"github.com/spf13/viper"
)

// InstallSettings are the settings for the installer.
type InstallSettings struct {
	args *Arguments

	installDir string
	cloneDir   string

	promptCtx prompt.IContext

	hookTemplateDir string
}

var log cm.ILogContext
var args = Arguments{}

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "githooks-installer",
	Short: "Githooks installer application",
	Long: "Githooks installer application\n" +
		"See further information at https://github.com/rycus86/githooks/blob/master/README.md",
	Run: runInstall}

// ProxyWriterOut is solely used for the cobra logging.
type ProxyWriterOut struct {
	log cm.ILogContext
}

// ProxyWriterErr is solely used for the cobra logging.
type ProxyWriterErr struct {
	log cm.ILogContext
}

func (p *ProxyWriterOut) Write(s []byte) (int, error) {
	return p.log.GetInfoWriter().Write([]byte(p.log.ColorInfo(string(s))))
}

func (p *ProxyWriterErr) Write(s []byte) (int, error) {
	return p.log.GetErrorWriter().Write([]byte(p.log.ColorError(string(s))))
}

// Run adds all child commands to the root command and sets flags appropriately.
// This is called by main.main(). It only needs to happen once to the rootCmd.
func Run() {
	cobra.OnInitialize(initArgs)

	rootCmd.SetOut(&ProxyWriterOut{log: log})
	rootCmd.SetErr(&ProxyWriterErr{log: log})
	rootCmd.Version = build.BuildVersion

	defineArguments(rootCmd)

	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}

func initArgs() {

	viper.BindEnv("internalAutoUpdate", "GITHOOKS_INTERNAL_AUTO_UPDATE")

	config := viper.GetString("config")
	if strs.IsNotEmpty(config) {
		viper.SetConfigFile(config)
		err := viper.ReadInConfig()
		log.AssertNoErrorFatalF(err, "Could not read config file '%s'.", config)
	}

	err := viper.Unmarshal(&args)
	log.AssertNoErrorFatalF(err, "Could not unmarshal parameters.")
}

func writeArgs(file string, args *Arguments) {
	err := cm.StoreJSON(file, args)
	log.AssertNoErrorFatalF(err, "Could not write arguments to '%s'.", file)
}

func defineArguments(rootCmd *cobra.Command) {
	// Internal commands
	rootCmd.PersistentFlags().String("config", "",
		"JSON config according to the 'Arguments' struct.")
	rootCmd.MarkPersistentFlagDirname("config")
	rootCmd.PersistentFlags().MarkHidden("config")

	rootCmd.PersistentFlags().Bool("internal-auto-update", false,
		"Internal argument, do not use!") // @todo Remove this...

	// User commands
	rootCmd.PersistentFlags().Bool("dry-run", false,
		"Dry run the installation showing whats beeing done.")

	rootCmd.PersistentFlags().Bool(
		"non-interactive", false,
		"Run the installation non-interactively\n"+
			"without showing prompts.")

	rootCmd.PersistentFlags().Bool(
		"single", false,
		"Install Githooks in the active repository only.\n"+
			"This does not mean it won't install necessary\n"+
			"files into the installation directory.")

	rootCmd.PersistentFlags().Bool(
		"skip-install-into-existing", false,
		"Skip installation into existing repositories\n"+
			"defined by a search path.")

	rootCmd.PersistentFlags().String(
		"prefix", "",
		"Githooks installation prefix such that\n"+
			"'<prefix>/.githooks' will be the installation directory.")
	rootCmd.MarkPersistentFlagDirname("config")

	rootCmd.PersistentFlags().String(
		"template-dir", "",
		"The preferred template directory to use.")

	rootCmd.PersistentFlags().Bool(
		"only-server-hooks", false,
		"Only install and maintain server hooks.")

	rootCmd.PersistentFlags().Bool(
		"use-core-hookspath", false,
		"If the install mode 'core.hooksPath' should be used.")

	rootCmd.PersistentFlags().String(
		"clone-url", "",
		"The clone url from which Githooks should clone\n"+
			"and install itself.")

	rootCmd.PersistentFlags().String(
		"clone-branch", "",
		"The clone branch from which Githooks should\n"+
			"clone and install itself.")

	rootCmd.PersistentFlags().Bool(
		"build-from-source", false,
		"If the binaries are built from source instead of\n"+
			"downloaded from the deploy url.")

	rootCmd.PersistentFlags().StringSlice(
		"build-flags", nil,
		"Build flags for building from source (get extended with defaults).")

	rootCmd.PersistentFlags().Bool(
		"stdin", false,
		"Use standard input to read prompt answers.")

	rootCmd.Args = cobra.NoArgs

	viper.BindPFlag("config", rootCmd.PersistentFlags().Lookup("config"))
	viper.BindPFlag("internalAutoUpdate", rootCmd.PersistentFlags().Lookup("internal-auto-update")) // @todo Remove this...
	viper.BindPFlag("dryRun", rootCmd.PersistentFlags().Lookup("dry-run"))
	viper.BindPFlag("nonInteractive", rootCmd.PersistentFlags().Lookup("non-interactive"))
	viper.BindPFlag("singleInstall", rootCmd.PersistentFlags().Lookup("single"))
	viper.BindPFlag("skipInstallIntoExisting", rootCmd.PersistentFlags().Lookup("skip-install-into-existing"))
	viper.BindPFlag("onlyServerHooks", rootCmd.PersistentFlags().Lookup("only-server-hooks"))
	viper.BindPFlag("useCoreHooksPath", rootCmd.PersistentFlags().Lookup("use-core-hookspath"))
	viper.BindPFlag("cloneURL", rootCmd.PersistentFlags().Lookup("clone-url"))
	viper.BindPFlag("cloneBranch", rootCmd.PersistentFlags().Lookup("clone-branch"))
	viper.BindPFlag("buildFromSource", rootCmd.PersistentFlags().Lookup("build-from-source"))
	viper.BindPFlag("buildFlags", rootCmd.PersistentFlags().Lookup("build-flags"))
	viper.BindPFlag("installPrefix", rootCmd.PersistentFlags().Lookup("prefix"))
	viper.BindPFlag("templateDir", rootCmd.PersistentFlags().Lookup("template-dir"))
	viper.BindPFlag("useStdin", rootCmd.PersistentFlags().Lookup("stdin"))
}

func validateArgs(cmd *cobra.Command, args *Arguments) {

	// Check all parsed flags to not have empty value!
	cmd.PersistentFlags().VisitAll(func(f *pflag.Flag) {
		log.FatalIfF(f.Changed && strs.IsEmpty(f.Value.String()),
			"Flag '%s' needs an non-empty value.", f.Name)
	})

	log.FatalIfF(args.SingleInstall && args.UseCoreHooksPath,
		"Cannot use --single and --use-core-hookspath together. See `--help`.")
}

func setMainVariables(args *Arguments) InstallSettings {

	var promptCtx prompt.IContext
	var err error

	if !args.NonInteractive {
		promptCtx, err = prompt.CreateContext(log, &cm.ExecContext{}, nil, false, args.UseStdin)
		log.AssertNoErrorF(err, "Prompt setup failed -> using fallback.")
	}

	var installDir string
	// First check if we already have
	// an install directory set (from --prefix)
	if strs.IsNotEmpty(args.InstallPrefix) {
		var err error
		args.InstallPrefix, err = cm.ReplaceTilde(filepath.ToSlash(args.InstallPrefix))
		log.AssertNoErrorFatal(err, "Could not replace '~' character in path.")
		installDir = path.Join(args.InstallPrefix, ".githooks")

	} else {
		installDir = hooks.GetInstallDir()
		if !cm.IsDirectory(installDir) {
			log.WarnF("Install directory '%s' does not exist.\n"+
				"Setting to default '~/.githooks'.", installDir)
			installDir = ""
		}
	}

	if strs.IsEmpty(installDir) {
		installDir, err = homedir.Dir()
		cm.AssertNoErrorPanic(err, "Could not get home directory.")
		installDir = path.Join(filepath.ToSlash(installDir), hooks.HookDirName)
	}

	return InstallSettings{
		args:       args,
		installDir: installDir,
		cloneDir:   hooks.GetReleaseCloneDir(installDir),
		promptCtx:  promptCtx}
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
	binPath, err := builder.Build(tempDir, settings.args.BuildFlags)
	log.AssertNoErrorFatalF(err, "Could not build release branch in '%s'.", tempDir)

	bins, err := cm.GetAllFiles(binPath)
	log.AssertNoErrorFatalF(err, "Could not get files in path '%s'.", binPath)

	binaries := updates.Binaries{BinDir: binPath}
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

func downloadBinaries(settings *InstallSettings, tempDir string, status updates.ReleaseStatus) updates.Binaries {
	log.Fatal("Not implemented")
	return updates.Binaries{}
}

func prepareDispatch(settings *InstallSettings) {

	var status updates.ReleaseStatus
	var err error

	if args.InternalAutoUpdate {

		status, err = updates.GetStatus(settings.cloneDir, true)
		log.AssertNoErrorFatal(err,
			"Could not get status of release clone '%s'",
			settings.cloneDir)

	} else {

		status, err = updates.FetchUpdates(
			settings.cloneDir,
			settings.args.CloneURL,
			settings.args.CloneBranch,
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
	if settings.args.BuildFromSource || updateSettings.DoBuildFromSource {
		binaries = buildFromSource(
			settings, tempDir,
			status.RemoteURL, status.Branch, status.RemoteCommitSHA)
	} else {
		_ = downloadBinaries(settings, tempDir, status)
	}

	updateTo := ""
	if status.LocalCommitSHA != status.RemoteCommitSHA {
		updateTo = status.RemoteCommitSHA
	}

	runInstaller(binaries.Installer, args, tempDir, updateTo, binaries.All)
}

func runInstaller(installer string, args Arguments, tempDir string, updateTo string, binaries []string) {
	log.Info("Dispatching to build installer ...")

	// Set variables...
	args.InternalPostUpdate = true
	args.InternalUpdateTo = updateTo
	args.InternalBinaries = binaries

	file, err := ioutil.TempFile(tempDir, "*install-config.json")
	log.AssertNoErrorFatalF(err, "Could not create temporary file in '%s'.", tempDir)
	defer os.Remove(file.Name())

	// Write the config ...
	writeArgs(file.Name(), &args)

	// Run the installer binary
	err = cm.RunExecutable(
		&cm.ExecContext{},
		&cm.Executable{Path: installer},
		true,
		"--config", file.Name())

	log.AssertNoErrorFatal(err, "Running installer failed.")
}

func disableStdInput() {
	null, _ := os.Open(os.DevNull)
	os.Stdin = null
}

func checkTemplateDir(targetDir string) string {
	if strs.IsEmpty(targetDir) {
		return ""
	}

	if cm.IsWritable(targetDir) {
		return targetDir
	}

	targetDir, err := cm.ReplaceTilde(targetDir)
	log.AssertNoErrorFatalF(err,
		"Could not replace tilde '~' in '%s'.", targetDir)

	if cm.IsWritable(targetDir) {
		return targetDir
	}

	return ""
}

// findGitHookTemplates returns the Git hook template directory
// and optional a Git template dir which is only set in case of
// not using the core.hooksPath method.
func findGitHookTemplates(settings *InstallSettings) (string, string) {
	args := settings.args

	installUsesCoreHooksPath := git.Ctx().GetConfig("githooks.useCoreHooksPath", git.GlobalScope)
	haveInstallation := strs.IsNotEmpty(installUsesCoreHooksPath)

	// 1. Try setup from environment variables
	gitTempDir, exists := os.LookupEnv("GIT_TEMPLATE_DIR")
	if exists {
		templateDir := checkTemplateDir(gitTempDir)

		if strs.IsNotEmpty(templateDir) {
			return path.Join(templateDir, "hooks"), ""
		}
	}

	// 2. Try setup from git config
	if args.UseCoreHooksPath || installUsesCoreHooksPath == "true" {
		hooksTemplateDir := checkTemplateDir(
			git.Ctx().GetConfig("core.hooksPath", git.GlobalScope))

		if strs.IsNotEmpty(hooksTemplateDir) {
			return hooksTemplateDir, ""
		}
	} else {
		templateDir := checkTemplateDir(
			git.Ctx().GetConfig("init.templateDir", git.GlobalScope))

		if strs.IsNotEmpty(templateDir) {
			return path.Join(templateDir, "hooks"), ""
		}
	}

	// 3. Try setup from the default location
	hooksTemplateDir := checkTemplateDir(path.Join(git.GetDefaultTemplateDir(), "hooks"))
	if strs.IsNotEmpty(hooksTemplateDir) {
		return hooksTemplateDir, ""
	}

	// If we have an installation, and have not found
	// the template folder by now...
	log.FatalIfF(haveInstallation,
		"Your installation is corrupt.\n"+
			"The global value 'githooks.useCoreHooksPath = %v'\n"+
			"is set but the corresponding hook templates directory\n"+
			"is not found.")

	// 4. Try setup new folder if running non-interactively
	// and no folder is found by now
	if args.NonInteractive {
		templateDir := setupNewTemplateDir(settings.installDir, nil)
		return path.Join(templateDir, "hooks"), templateDir
	}

	// 5. Try to search for it on disk
	answer, err := settings.promptCtx.ShowPromptOptions(
		"Could not find the Git hook template directory.\n"+
			"Do you want to search for it?",
		"(yes, No)",
		"y/N",
		"Yes", "No")
	log.AssertNoErrorF(err, "Could not show prompt.")

	if answer == "y" {
		templateDir := searchTemplateDirOnDisk(settings)

		if strs.IsNotEmpty(templateDir) {

			if settings.args.UseCoreHooksPath {
				return path.Join(templateDir, "hooks"), ""
			}

			// If we dont use core.hooksPath, we ask
			// if the user wants to continue setting this as
			// 'init.templateDir'.
			answer, err := settings.promptCtx.ShowPromptOptions(
				"Do you want to set this up as the Git template\n"+
					"directory (e.g setting 'init.templateDir')\n"+
					"for future use?",
				"(yes, No (abort))",
				"y/N",
				"Yes", "No (abort)")
			log.AssertNoErrorF(err, "Could not show prompt.")

			log.FatalIf(answer != "y",
				"Could not determine Git hook",
				"templates directory. -> Abort.")

			return path.Join(templateDir, "hooks"), templateDir
		}
	}

	// 6. Set up as new
	answer, err = settings.promptCtx.ShowPromptOptions(
		"Do you want to set up a new Git templates folder?",
		"(yes, No)",
		"y/N",
		"Yes", "No")
	log.AssertNoErrorF(err, "Could not show prompt.")

	if answer == "y" {
		templateDir := setupNewTemplateDir(settings.installDir, settings.promptCtx)
		return path.Join(templateDir, "hooks"), templateDir
	}

	return "", ""
}

func searchTemplateDirOnDisk(settings *InstallSettings) string {
	return ""
}

func setupNewTemplateDir(installDir string, promptCtx prompt.IContext) string {
	templateDir := path.Join(installDir, "templates")

	if promptCtx != nil {
		var err error
		templateDir, err = promptCtx.ShowPrompt(
			"Enter the target folder", templateDir, false)
		log.AssertNoErrorF(err, "Could not show prompt.")
	}

	templateDir, err := cm.ReplaceTilde(templateDir)
	log.AssertNoErrorFatalF(err, "Could not replace tilde '~' in '%s'.", templateDir)

	return templateDir
}

func setTargetTemplateDir(settings *InstallSettings) {
	templateDir := settings.args.TemplateDir

	if strs.IsEmpty(templateDir) {
		// Automatically find a template directory.
		settings.hookTemplateDir, templateDir = findGitHookTemplates(settings)
		log.FatalIfF(strs.IsEmpty(settings.hookTemplateDir),
			"Could not determine Git hook template directory.")
	} else {
		// The user provided a template directory, check it and
		// add `hooks` which is needed.
		log.FatalIfF(!cm.IsDirectory(templateDir),
			"Given template dir '%s' does not exist.", templateDir)
		settings.hookTemplateDir = path.Join(templateDir, "hooks")
	}

	log.DebugF("Hook template dir: '%s'.", settings.hookTemplateDir)

	err := os.MkdirAll(settings.hookTemplateDir, 0775)
	log.AssertNoErrorFatalF(err,
		"Could not assert directory '%s' exists",
		settings.hookTemplateDir)

	// Set the global Git configuration
	if settings.args.UseCoreHooksPath {
		setGithooksDirectory(true, settings.hookTemplateDir, settings.args.DryRun)
	} else {
		setGithooksDirectory(false, templateDir, settings.args.DryRun)
	}
}

func setGithooksDirectory(useCoreHooksPath bool, directory string, dryRun bool) {
	gitx := git.Ctx()

	prefix := "Setting"
	if dryRun {
		prefix = "Would set"
	}

	if useCoreHooksPath {

		log.InfoF("%s 'core.hooksPath' to '%s'.", prefix, directory)

		if !dryRun {
			err := gitx.SetConfig("githooks.useCoreHooksPath", true, git.GlobalScope)
			log.AssertNoErrorFatal(err, "Could not set Git config value.")

			err = gitx.SetConfig("githooks.pathForUseCoreHooksPath", directory, git.GlobalScope)
			log.AssertNoErrorFatal(err, "Could not set Git config value.")

			err = gitx.SetConfig("core.hooksPath", directory, git.GlobalScope)
			log.AssertNoErrorFatal(err, "Could not set Git config value.")
		}

		// Warnings:
		// Check if hooks might not run...
		tD := gitx.GetConfig("init.templateDir", git.GlobalScope)
		msg := ""
		if strs.IsNotEmpty(tD) && cm.IsDirectory(path.Join(tD, "hooks")) {
			d := path.Join(tD, "hooks")
			files, err := cm.GetAllFiles(d)
			log.AssertNoErrorFatalF(err, "Could not get files in '%s'.", d)

			if len(files) > 0 {
				msg = strs.Fmt(
					"The 'init.templateDir' setting is currently set to\n"+
						"'%s'\n"+
						"and contains '%v' potential hooks.\n", tD, len(files))
			}
		}

		tDEnv := os.Getenv("GIT_TEMPLATE_DIR")
		if strs.IsNotEmpty(tDEnv) && cm.IsDirectory(path.Join(tDEnv, "hooks")) {
			d := path.Join(tDEnv, "hooks")
			files, err := cm.GetAllFiles(d)
			log.AssertNoErrorFatalF(err, "Could not get files in '%s'.", d)

			if len(files) > 0 {
				msg += strs.Fmt(
					"The environment variable 'GIT_TEMPLATE_DIR' is currently set to\n"+
						"'%s'\n"+
						"and contains '%v' potential hooks.\n", tDEnv, len(files))
			}
		}

		log.WarnIf(strs.IsNotEmpty(msg),
			msg+
				"These hooks might get installed but\n"+
				"ignored because 'core.hooksPath' is also set.\n"+
				"It is recommended to either remove the files or run\n"+
				"the Githooks installation without the '--use-core-hookspath'\n"+
				"parameter.")

	} else {

		if !dryRun {
			err := gitx.SetConfig("githooks.useCoreHooksPath", false, git.GlobalScope)
			log.AssertNoErrorFatal(err, "Could not set Git config value.")
		}

		if strs.IsNotEmpty(directory) {
			log.InfoF("%s 'init.templateDir' to '%s'.", prefix, directory)

			if !dryRun {
				err := gitx.SetConfig("init.templateDir", directory, git.GlobalScope)
				log.AssertNoErrorFatal(err, "Could not set Git config value.")
			}
		}

		// Warnings:
		// Check if hooks might not run..
		hP := gitx.GetConfig("core.hooksPath", git.GlobalScope)
		log.WarnIfF(strs.IsNotEmpty(hP),
			"The 'core.hooksPath' setting is currently set to\n"+
				"'%s'\n"+
				"This could mean that Githooks hooks will be ignored\n"+
				"Either unset 'core.hooksPath' or run the Githooks\n"+
				"installation with the '--use-core-hookspath' parameter.",
			hP)

	}
}

func runUpdate(settings *InstallSettings) {
	log.InfoF("Running update to version '%s' ...", build.BuildVersion)
	log.InfoF("Installing binaries in '%v'", settings.args.InternalBinaries)

	if settings.args.NonInteractive {
		disableStdInput()
	}

	setTargetTemplateDir(settings)
}

func runInstall(cmd *cobra.Command, auxArgs []string) {

	log.DebugF("Arguments: %+v", args)
	validateArgs(cmd, &args)

	settings := setMainVariables(&args)

	if !args.DryRun {
		setInstallDirAndRunner(settings.installDir)
	}

	if !args.InternalPostUpdate {
		prepareDispatch(&settings)
	} else {
		runUpdate(&settings)
	}

}

func main() {

	cwd, err := os.Getwd()
	cm.AssertNoErrorPanic(err, "Could not get current working dir.")
	cwd = filepath.ToSlash(cwd)

	log, err = cm.CreateLogContext(cm.IsRunInDocker)
	cm.AssertOrPanic(err == nil, "Could not create log")

	log.InfoF("Installer [version: %s]", build.BuildVersion)

	var exitCode int
	defer func() { os.Exit(exitCode) }()

	// Handle all panics and report the error
	defer func() {
		r := recover()
		if hooks.HandleCLIErrors(r, cwd, log) {
			exitCode = 1
		}
	}()

	Run()
}
