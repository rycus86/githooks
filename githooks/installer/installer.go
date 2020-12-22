//go:generate go run -mod=vendor ../tools/embed-files.go
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
	"time"

	"github.com/mitchellh/go-homedir"
	"github.com/spf13/cobra"
	"github.com/spf13/pflag"
	"github.com/spf13/viper"
)

// InstallSettings are the settings for the installer.
type InstallSettings struct {
	Cwd        string // The current working directory.
	InstallDir string // The install directory.
	CloneDir   string // The release clone dir inside the install dir.
	TempDir    string // The temporary directory inside the install dir.

	PromptCtx prompt.IContext // The prompt context for UI prompts.

	HookTemplateDir string // The chosen hook template directory.
}

var log cm.ILogContext
var args = Arguments{}

// rootCmd represents the base command when called without any subcommands.
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

	err := viper.BindEnv("internalAutoUpdate", "GITHOOKS_INTERNAL_AUTO_UPDATE")
	cm.AssertNoErrorPanic(err)

	config := viper.GetString("config")
	if strs.IsNotEmpty(config) {
		viper.SetConfigFile(config)
		err := viper.ReadInConfig()
		log.AssertNoErrorPanicF(err, "Could not read config file '%s'.", config)
	}

	err = viper.Unmarshal(&args)
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
	err := rootCmd.MarkPersistentFlagDirname("config")
	cm.AssertNoErrorPanic(err)
	err = rootCmd.PersistentFlags().MarkHidden("config")
	cm.AssertNoErrorPanic(err)

	rootCmd.PersistentFlags().Bool("internal-auto-update", false,
		"Internal argument, do not use!") // @todo Remove this...

	// User commands
	rootCmd.PersistentFlags().Bool("dry-run", false,
		"Dry run the installation showing whats being done.")

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
	err = rootCmd.MarkPersistentFlagDirname("config")
	cm.AssertNoErrorPanic(err)

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
		"build-tags", nil,
		"Build tags for building from source (get extended with defaults).")

	rootCmd.PersistentFlags().Bool(
		"stdin", false,
		"Use standard input to read prompt answers.")

	rootCmd.Args = cobra.NoArgs

	err = viper.BindPFlag("config", rootCmd.PersistentFlags().Lookup("config"))
	cm.AssertNoErrorPanic(err)
	// @todo Remove this internalAutoUpdate...
	err = viper.BindPFlag("internalAutoUpdate", rootCmd.PersistentFlags().Lookup("internal-auto-update"))
	cm.AssertNoErrorPanic(err)
	err = viper.BindPFlag("dryRun", rootCmd.PersistentFlags().Lookup("dry-run"))
	cm.AssertNoErrorPanic(err)
	err = viper.BindPFlag("nonInteractive", rootCmd.PersistentFlags().Lookup("non-interactive"))
	cm.AssertNoErrorPanic(err)
	err = viper.BindPFlag("singleInstall", rootCmd.PersistentFlags().Lookup("single"))
	cm.AssertNoErrorPanic(err)
	err = viper.BindPFlag("skipInstallIntoExisting", rootCmd.PersistentFlags().Lookup("skip-install-into-existing"))
	cm.AssertNoErrorPanic(err)
	err = viper.BindPFlag("onlyServerHooks", rootCmd.PersistentFlags().Lookup("only-server-hooks"))
	cm.AssertNoErrorPanic(err)
	err = viper.BindPFlag("useCoreHooksPath", rootCmd.PersistentFlags().Lookup("use-core-hookspath"))
	cm.AssertNoErrorPanic(err)
	err = viper.BindPFlag("cloneURL", rootCmd.PersistentFlags().Lookup("clone-url"))
	cm.AssertNoErrorPanic(err)
	err = viper.BindPFlag("cloneBranch", rootCmd.PersistentFlags().Lookup("clone-branch"))
	cm.AssertNoErrorPanic(err)
	err = viper.BindPFlag("buildFromSource", rootCmd.PersistentFlags().Lookup("build-from-source"))
	cm.AssertNoErrorPanic(err)
	err = viper.BindPFlag("buildTags", rootCmd.PersistentFlags().Lookup("build-tags"))
	cm.AssertNoErrorPanic(err)
	err = viper.BindPFlag("installPrefix", rootCmd.PersistentFlags().Lookup("prefix"))
	cm.AssertNoErrorPanic(err)
	err = viper.BindPFlag("templateDir", rootCmd.PersistentFlags().Lookup("template-dir"))
	cm.AssertNoErrorPanic(err)
	err = viper.BindPFlag("useStdin", rootCmd.PersistentFlags().Lookup("stdin"))
	cm.AssertNoErrorPanic(err)
}

func validateArgs(cmd *cobra.Command, args *Arguments) {

	// Check all parsed flags to not have empty value!
	cmd.PersistentFlags().VisitAll(func(f *pflag.Flag) {
		log.PanicIfF(f.Changed && strs.IsEmpty(f.Value.String()),
			"Flag '%s' needs an non-empty value.", f.Name)
	})

	log.PanicIfF(args.SingleInstall && args.UseCoreHooksPath,
		"Cannot use --single and --use-core-hookspath together. See `--help`.")
}

func setMainVariables(args *Arguments) (InstallSettings, UISettings) {

	var promptCtx prompt.IContext
	var err error

	cwd, err := os.Getwd()
	log.AssertNoErrorPanic(err, "Could not get current working directory.")

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
		log.AssertNoErrorPanic(err, "Could not replace '~' character in path.")
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

	// Remove temporary directory if existing
	tempDir, err := hooks.CleanTemporaryDir(installDir)
	log.AssertNoErrorPanicF(err, "Could not clean temporary directory in '%s'", installDir)

	return InstallSettings{
			Cwd:        cwd,
			InstallDir: installDir,
			CloneDir:   hooks.GetReleaseCloneDir(installDir),
			TempDir:    tempDir},
		UISettings{PromptCtx: promptCtx}
}

func setInstallDir(installDir string) {
	log.AssertNoErrorPanic(hooks.SetInstallDir(installDir),
		"Could not set install dir '%s'", installDir)
}

func buildFromSource(
	buildTags []string,
	tempDir string,
	url string,
	branch string,
	commitSHA string) updates.Binaries {

	log.Info("Building binaries from source ...")

	// Clone another copy of the release clone into temporary directory
	log.InfoF("Clone to temporary build directory '%s'", tempDir)
	err := git.Clone(tempDir, url, branch, -1)
	log.AssertNoErrorPanicF(err, "Could not clone release branch into '%s'.", tempDir)

	// Checkout the remote commit sha
	log.InfoF("Checkout out commit '%s'", commitSHA[0:6])
	gitx := git.CtxC(tempDir)
	err = gitx.Check("checkout",
		"-b", "update-to-"+commitSHA[0:6],
		commitSHA)

	log.AssertNoErrorPanicF(err,
		"Could not checkout update commit '%s' in '%s'.",
		commitSHA, tempDir)

	tag, _ := gitx.Get("describe", "--tags", "--abbrev=6")
	log.InfoF("Building binaries at '%s'", tag)

	// Build the binaries.
	binPath, err := builder.Build(tempDir, buildTags)
	log.AssertNoErrorPanicF(err, "Could not build release branch in '%s'.", tempDir)

	bins, err := cm.GetAllFiles(binPath)
	log.AssertNoErrorPanicF(err, "Could not get files in path '%s'.", binPath)

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
			strs.Map(binaries.All, path.Base),
			"\n - "))

	log.PanicIf(
		len(binaries.All) == 0 ||
			strs.IsEmpty(binaries.Installer),
		"No binaries found in '%s'", binPath)

	return binaries
}

func prepareDispatch(settings *InstallSettings, args *Arguments) bool {

	var status updates.ReleaseStatus
	var err error

	if args.InternalAutoUpdate {

		status, err = updates.GetStatus(settings.CloneDir, true)
		log.AssertNoErrorPanic(err,
			"Could not get status of release clone '%s'",
			settings.CloneDir)

	} else {

		status, err = updates.FetchUpdates(
			settings.CloneDir,
			args.CloneURL,
			args.CloneBranch,
			true, updates.RecloneOnWrongRemote)

		log.AssertNoErrorPanicF(err,
			"Could not assert release clone '%s' existing",
			settings.CloneDir)
	}

	updateAvailable := status.LocalCommitSHA != status.RemoteCommitSHA
	haveInstaller := cm.IsFile(hooks.GetInstallerExecutable(settings.InstallDir))

	// We download/build the binaries if an update is available
	// or the installer is missing.
	binaries := updates.Binaries{}

	if updateAvailable || !haveInstaller {

		log.Info("Getting Githooks binaries...")

		tempDir, err := ioutil.TempDir(os.TempDir(), "*-githooks-update")
		log.AssertNoErrorPanic(err, "Can not create temporary update dir in '%s'", os.TempDir())
		defer os.RemoveAll(tempDir)

		if args.BuildFromSource {
			binaries = buildFromSource(
				args.BuildTags,
				tempDir,
				status.RemoteURL,
				status.Branch,
				status.RemoteCommitSHA)
		} else {
			binaries = downloadBinaries(settings, tempDir, status)
		}
	}

	updateTo := ""
	if updateAvailable {
		updateTo = status.RemoteCommitSHA
	}

	return runInstaller(
		binaries.Installer,
		args,
		updateTo,
		binaries.All)
}

func runInstaller(
	installer string,
	args *Arguments,
	updateTo string,
	binaries []string) bool {

	log.Info("Dispatching to build installer ...")

	// Set variables...
	args.InternalPostUpdate = true
	args.InternalUpdateTo = updateTo
	args.InternalBinaries = binaries

	if IsDispatchSkipped {
		return false
	}

	file, err := ioutil.TempFile("", "*install-config.json")
	log.AssertNoErrorPanicF(err, "Could not create temporary file in '%s'.")
	defer os.Remove(file.Name())

	// Write the config ...
	writeArgs(file.Name(), args)

	// Run the installer binary
	err = cm.RunExecutable(
		&cm.ExecContext{},
		&cm.Executable{Path: installer},
		true,
		"--config", file.Name())

	log.AssertNoErrorPanic(err, "Running installer failed.")

	return true
}

func checkTemplateDir(targetDir string) string {
	if strs.IsEmpty(targetDir) {
		return ""
	}

	if cm.IsWritable(targetDir) {
		return targetDir
	}

	targetDir, err := cm.ReplaceTilde(targetDir)
	log.AssertNoErrorPanicF(err,
		"Could not replace tilde '~' in '%s'.", targetDir)

	if cm.IsWritable(targetDir) {
		return targetDir
	}

	return ""
}

// findGitHookTemplates returns the Git hook template directory
// and optional a Git template dir which is only set in case of
// not using the core.hooksPath method.
func findGitHookTemplates(
	installDir string,
	useCoreHooksPath bool,
	nonInteractive bool,
	promptCtx prompt.IContext) (string, string) {

	installUsesCoreHooksPath := git.Ctx().GetConfig("githooks.useCoreHooksPath", git.GlobalScope)
	haveInstall := strs.IsNotEmpty(installUsesCoreHooksPath)

	// 1. Try setup from environment variables
	gitTempDir, exists := os.LookupEnv("GIT_TEMPLATE_DIR")
	if exists {
		templateDir := checkTemplateDir(gitTempDir)

		if strs.IsNotEmpty(templateDir) {
			return path.Join(templateDir, "hooks"), ""
		}
	}

	// 2. Try setup from git config
	if useCoreHooksPath || installUsesCoreHooksPath == "true" {
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
	log.PanicIfF(haveInstall,
		"Your installation is corrupt.\n"+
			"The global value 'githooks.useCoreHooksPath = %v'\n"+
			"is set but the corresponding hook templates directory\n"+
			"is not found.", installUsesCoreHooksPath)

	// 4. Try setup new folder if running non-interactively
	// and no folder is found by now
	if nonInteractive {
		templateDir := setupNewTemplateDir(installDir, nil)
		return path.Join(templateDir, "hooks"), templateDir //nolint:nlreturn
	}

	// 5. Try to search for it on disk
	answer, err := promptCtx.ShowPromptOptions(
		"Could not find the Git hook template directory.\n"+
			"Do you want to search for it?",
		"(yes, No)",
		"y/N",
		"Yes", "No")
	log.AssertNoErrorF(err, "Could not show prompt.")

	if answer == "y" {

		templateDir := searchTemplateDirOnDisk(promptCtx)

		if strs.IsNotEmpty(templateDir) {

			if useCoreHooksPath {
				return path.Join(templateDir, "hooks"), ""
			}

			// If we dont use core.hooksPath, we ask
			// if the user wants to continue setting this as
			// 'init.templateDir'.
			answer, err := promptCtx.ShowPromptOptions(
				"Do you want to set this up as the Git template\n"+
					"directory (e.g setting 'init.templateDir')\n"+
					"for future use?",
				"(yes, No (abort))",
				"y/N",
				"Yes", "No (abort)")
			log.AssertNoErrorF(err, "Could not show prompt.")

			log.PanicIf(answer != "y",
				"Could not determine Git hook",
				"templates directory. -> Abort.")

			return path.Join(templateDir, "hooks"), templateDir
		}
	}

	// 6. Set up as new
	answer, err = promptCtx.ShowPromptOptions(
		"Do you want to set up a new Git templates folder?",
		"(yes, No)",
		"y/N",
		"Yes", "No")
	log.AssertNoErrorF(err, "Could not show prompt.")

	if answer == "y" {
		templateDir := setupNewTemplateDir(installDir, promptCtx)
		return path.Join(templateDir, "hooks"), templateDir //nolint:nlreturn
	}

	return "", ""
}

func searchPreCommitFile(startDirs []string, promptCtx prompt.IContext) string {

	for _, dir := range startDirs {

		log.InfoF("Searching for potential locations in '%s'...", dir)

		spinner := cm.GetProgressBar(log, "Searching ...", -1)

		// Search in go routine...
		matchCh := make(chan []string, 1)
		go func() {
			matches, err := cm.Glob(path.Join(dir,
				"**/templates/hooks/pre-commit.sample"))
			if err == nil {
				matchCh <- matches
			}
		}()

		var matches []string
		running := true

		spinnerT := time.NewTicker(10 * time.Millisecond) //nolint:gomnd
		stillSearching := time.After(10 * time.Second)    //nolint:gomnd
		timeout := time.After(300 * time.Second)          //nolint:gomnd

		for running {
			select {
			case matches = <-matchCh:
				running = false
				if spinner != nil {
					_ = spinner.Clear()
				}

			case <-stillSearching:
				if spinner == nil {
					log.Info("Still searching ...")
				} else {
					spinner.Describe("Still searching ...")
				}
			case <-spinnerT.C:
				if spinner != nil {
					_ = spinner.Add(1)
				}
			case <-timeout:
				log.Warn("Searching took too long -> timed out.")
				running = false
			}
		}

		for _, match := range matches {

			templateDir := path.Dir(path.Dir(filepath.ToSlash(match)))

			answer, err := promptCtx.ShowPromptOptions(
				strs.Fmt("--> Is it '%s'", templateDir),
				"(yes, No)",
				"y/N",
				"Yes", "No")
			log.AssertNoErrorF(err, "Could not show prompt.")

			if answer == "y" {
				return templateDir
			}
		}
	}

	return ""
}

func searchTemplateDirOnDisk(promptCtx prompt.IContext) string {

	first, second := GetDefaultTemplateSearchDir()

	templateDir := searchPreCommitFile(first, promptCtx)

	if strs.IsEmpty(templateDir) {

		answer, err := promptCtx.ShowPromptOptions(
			"Git hook template directory not found\n"+
				"Do you want to keep searching?",
			"(yes, No)",
			"y/N",
			"Yes", "No")

		log.AssertNoErrorF(err, "Could not show prompt.")

		if answer == "y" {
			templateDir = searchPreCommitFile(second, promptCtx)
		}
	}

	return templateDir
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
	log.AssertNoErrorPanicF(err, "Could not replace tilde '~' in '%s'.", templateDir)

	return templateDir
}

func getTargetTemplateDir(
	installDir string,
	templateDir string,
	useCoreHooksPath bool,
	nonInteractive bool,
	dryRun bool,
	promptCtx prompt.IContext) (hookTemplateDir string) {

	if strs.IsEmpty(templateDir) {
		// Automatically find a template directory.
		hookTemplateDir, templateDir = findGitHookTemplates(
			installDir,
			useCoreHooksPath,
			nonInteractive,
			promptCtx)

		log.PanicIfF(strs.IsEmpty(hookTemplateDir),
			"Could not determine Git hook template directory.")
	} else {
		// The user provided a template directory, check it and
		// add `hooks` which is needed.
		log.PanicIfF(!cm.IsDirectory(templateDir),
			"Given template dir '%s' does not exist.", templateDir)
		hookTemplateDir = path.Join(templateDir, "hooks")
	}

	err := os.MkdirAll(hookTemplateDir, cm.DefaultDirectoryFileMode)
	log.AssertNoErrorPanicF(err,
		"Could not assert directory '%s' exists",
		hookTemplateDir)

	// Set the global Git configuration
	if useCoreHooksPath {
		setGithooksDirectory(true, hookTemplateDir, dryRun)
	} else {
		setGithooksDirectory(false, templateDir, dryRun)
	}

	return
}

func setGithooksDirectory(useCoreHooksPath bool, directory string, dryRun bool) {
	gitx := git.Ctx()

	prefix := "Setting"
	if dryRun {
		prefix = "[dry run] Would set"
	}

	if useCoreHooksPath {

		log.InfoF("%s 'core.hooksPath' to '%s'.", prefix, directory)

		if !dryRun {
			err := gitx.SetConfig("githooks.useCoreHooksPath", true, git.GlobalScope)
			log.AssertNoErrorPanic(err, "Could not set Git config value.")

			err = gitx.SetConfig("githooks.pathForUseCoreHooksPath", directory, git.GlobalScope)
			log.AssertNoErrorPanic(err, "Could not set Git config value.")

			err = gitx.SetConfig("core.hooksPath", directory, git.GlobalScope)
			log.AssertNoErrorPanic(err, "Could not set Git config value.")
		}

		// Warnings:
		// Check if hooks might not run...
		tD := gitx.GetConfig("init.templateDir", git.GlobalScope)
		msg := ""
		if strs.IsNotEmpty(tD) && cm.IsDirectory(path.Join(tD, "hooks")) {
			d := path.Join(tD, "hooks")
			files, err := cm.GetAllFiles(d)
			log.AssertNoErrorPanicF(err, "Could not get files in '%s'.", d)

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
			log.AssertNoErrorPanicF(err, "Could not get files in '%s'.", d)

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
			log.AssertNoErrorPanic(err, "Could not set Git config value.")
		}

		if strs.IsNotEmpty(directory) {
			log.InfoF("%s 'init.templateDir' to '%s'.", prefix, directory)

			if !dryRun {
				err := gitx.SetConfig("init.templateDir", directory, git.GlobalScope)
				log.AssertNoErrorPanic(err, "Could not set Git config value.")
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

func setupHookTemplates(
	hookTemplateDir string,
	cloneDir string,
	tempDir string,
	onlyServerHooks bool,
	nonInteractive bool,
	dryRun bool,
	promptCtx prompt.IContext) {

	if dryRun {
		log.InfoF("[dry run] Would install Git hook templates into '%s'.",
			hookTemplateDir)
		return //nolint:nlreturn
	}

	log.InfoF("Installing Git hook templates into '%s'.",
		hookTemplateDir)

	var hookNames []string
	if onlyServerHooks {
		hookNames = managedServerHookNames
	} else {
		hookNames = managedHookNames
	}

	err := hooks.InstallRunWrappers(
		hookTemplateDir,
		hookNames,
		tempDir,
		getHookDisableCallback(log, nonInteractive, dryRun, promptCtx),
		log)

	log.AssertNoErrorPanicF(err, "Could not install run wrappers into '%s'.", hookTemplateDir)

	if onlyServerHooks {
		err := git.Ctx().SetConfig("githooks.maintainOnlyServerHooks", true, git.GlobalScope)
		log.AssertNoErrorPanic(err, "Could not set Git config 'githooks.maintainOnlyServerHooks'.")
	}
}

func installBinaries(
	installDir string,
	cloneDir string,
	tempDir string,
	binaries []string,
	dryRun bool) {

	binDir := hooks.GetBinaryDir(installDir)
	err := os.MkdirAll(binDir, cm.DefaultDirectoryFileMode)
	log.AssertNoErrorPanicF(err, "Could not create binary dir '%s'.", binDir)

	msg := strs.Map(binaries, func(s string) string { return strs.Fmt(" - '%s'", path.Base(s)) })
	if dryRun {
		log.InfoF("[dry run] Would install binaries:\n%s\n"+"to '%s'.", msg)
		return //nolint:nlreturn
	}

	log.InfoF("Installing binaries:\n%s\n"+"to '%s'.", strings.Join(msg, "\n"), binDir)

	for _, binary := range binaries {
		dest := path.Join(binDir, path.Base(binary))
		err := cm.MoveFileWithBackup(binary, dest, tempDir)
		log.AssertNoErrorPanicF(err,
			"Could not move file '%s' to '%s'.", binary, dest)
	}

	if hooks.InstallLegacyBinaries {
		src := path.Join(cloneDir, "cli.sh")
		dest := path.Join(binDir, path.Base(src))
		err := cm.CopyFile(src, dest)
		log.AssertNoErrorPanicF(err, "Could not copy legacy executable '%s'.", src)
	}

	// Set CLI executable alias.
	cliTool := hooks.GetCLIExecutable(installDir)
	err = hooks.SetCLIExecutableAlias(cliTool)
	log.AssertNoErrorPanicF(err,
		"Could not set Git config 'alias.hooks' to '%s'.", cliTool)

	if hooks.InstallLegacyBinaries {
		err = cm.MakeExecutbale(cliTool)
		log.AssertNoErrorPanicF(err, "Making file '%s' executable failed.", cliTool)
	}

	// Set runner executable alias.
	runner := hooks.GetRunnerExecutable(installDir)
	err = hooks.SetRunnerExecutableAlias(runner)
	log.AssertNoErrorPanic(err,
		"Could not set runner executable alias '%s'.", runner)
}

func setupAutomaticUpdate(nonInteractive bool, dryRun bool, promptCtx prompt.IContext) {
	gitx := git.Ctx()
	currentSetting := gitx.GetConfig("githooks.autoupdate.enable", git.GlobalScope)
	promptMsg := ""

	switch {
	case currentSetting == "true":
		return // Already enabled.
	case strs.IsEmpty(currentSetting):
		promptMsg = "Would you like to enable automatic update checks,\ndone once a day after a commit?"
	default:
		log.Info("Automatic update checks are currently disabled.")
		if nonInteractive {
			return
		}
		promptMsg = "Would you like to re-enable them,\ndone once a day after a commit?"
	}

	activate := false

	if nonInteractive {
		activate = true
	} else {
		answer, err := promptCtx.ShowPromptOptions(
			promptMsg,
			"(Yes, no)",
			"Y/n", "Yes", "No")
		log.AssertNoErrorF(err, "Could not show prompt.")

		activate = answer == "y"
	}

	if activate {
		if dryRun {
			log.Info("[dry run] Would enable automatic update checks.")
		} else {

			if err := gitx.SetConfig(
				"githooks.autoupdate.enabled", true, git.GlobalScope); err == nil {

				log.Info("Automatic update checks are now enabled.")
			} else {
				log.Error("Failed to enable automatic update checks.")
			}

		}
	} else {
		log.Info(
			"If you change your mind in the future, you can enable it by running:",
			"  $ git hooks update enable")
	}
}

func setupReadme(
	repoGitDir string,
	dryRun bool,
	uiSettings *UISettings) {

	mainWorktree, err := git.CtxC(repoGitDir).GetMainWorktree()
	if err != nil || !git.CtxC(mainWorktree).IsGitRepo() {
		log.WarnF("Main worktree could not be determined in:\n'%s'\n"+
			"-> Skipping Readme setup.",
			repoGitDir)

		return
	}

	hookDir := path.Join(mainWorktree, hooks.HookDirName)
	readme := hooks.GetReadmeFile(hookDir)

	if !cm.IsFile(readme) {

		createFile := false

		switch uiSettings.AnswerSetupIncludedReadme {
		case "s":
			// OK, we already said we want to skip all
			return
		case "a":
			createFile = true
		default:

			var msg string
			if cm.IsDirectory(hookDir) {
				msg = strs.Fmt(
					"Looks like you don't have a '%s' folder in repository\n"+
						"'%s' yet.\n"+
						"Would you like to create one with a 'README'\n"+
						"containing a brief overview of Githooks?", hooks.HookDirName, mainWorktree)
			} else {
				msg = strs.Fmt(
					"Looks like you don't have a 'README.md' in repository\n"+
						"'%s' yet.\n"+
						"A 'README' file might help contributors\n"+
						"and other team members learn about what is this for.\n"+
						"Would you like to add one now containing a\n"+
						"brief overview of Githooks?", hookDir)
			}

			answer, err := uiSettings.PromptCtx.ShowPromptOptions(
				msg, "(Yes, no, all, skip all)",
				"Y/n/a/s",
				"Yes", "No", "All", "Skip All")
			log.AssertNoError(err, "Could not show prompt.")

			switch answer {
			case "s":
				uiSettings.AnswerSetupIncludedReadme = answer
			case "a":
				uiSettings.AnswerSetupIncludedReadme = answer

				fallthrough
			case "y":
				createFile = true
			}
		}
		if createFile {

			if dryRun {
				log.InfoF("[dry run] Readme file '%s' would have been written.", readme)

				return
			}

			err := os.MkdirAll(path.Base(readme), cm.DefaultDirectoryFileMode)

			if err != nil {
				log.WarnF("Could not create directory for '%s'.\n"+
					"-> Skipping Readme setup.", readme)

				return
			}

			err = hooks.WriteReadmeFile(readme)
			log.AssertNoErrorF(err, "Could not write README file '%s'.", readme)
		}
	}
}

func installGitHooksIntoRepo(
	repoGitDir string,
	tempDir string,
	nonInteractive bool,
	dryRun bool,
	uiSettings *UISettings) {

	hookDir := path.Join(repoGitDir, "hooks")
	if !cm.IsDirectory(hookDir) {
		err := os.MkdirAll(hookDir, cm.DefaultDirectoryFileMode)
		log.AssertNoErrorPanic(err,
			"Could not create hook directory in '%s'.", repoGitDir)
	}

	isBare := git.CtxC(repoGitDir).IsBareRepo()

	var hookNames []string
	if isBare {
		hookNames = managedServerHookNames
	} else {
		hookNames = managedHookNames
	}

	err := hooks.InstallRunWrappers(
		hookDir, hookNames, tempDir,
		getHookDisableCallback(log, nonInteractive, dryRun, uiSettings.PromptCtx),
		nil)
	log.AssertNoErrorPanicF(err, "Could not install run wrappers into '%s'.", hookDir)

	// Offer to setup the intro README if running in interactive mode
	// Let's skip this in non-interactive mode or in a bare repository
	// to avoid polluting the repos with README files
	if !nonInteractive && !isBare {
		setupReadme(repoGitDir, dryRun, uiSettings)
	}

	if dryRun {
		log.InfoF("[dry run] Hooks would have been installed into\n'%s'.",
			repoGitDir)
	} else {
		log.InfoF("Hooks installed into\n'%s'.",
			repoGitDir)
	}
}

func getCurrentGitDir(cwd string) (gitDir string) {
	gitx := git.CtxC(cwd)
	log.PanicIfF(!gitx.IsGitRepo(),
		"The current directory is not a Git repository.")

	gitDir, err := gitx.GetGitCommonDir()
	cm.AssertNoErrorPanic(err, "Could not get git directory in '%s'.", cwd)

	return
}

func setupSharedHookRepositories() {

}

func thankYou() {
	log.InfoF("\nAll done! Enjoy!\n"+
		"Please support the project by starring the project\n"+
		"at '%s', and report\n"+
		"bugs or missing features or improvements as issues.\n"+
		"Thanks!\n", hooks.GithooksWebpage)
}

func runUpdate(
	settings *InstallSettings,
	uiSettings *UISettings,
	args *Arguments) {

	log.InfoF("Running update to version '%s' ...", build.BuildVersion)

	if args.NonInteractive {
		// disable the prompt context,
		// no prompt must be shown in this mode
		// if we do -> pandic...
		uiSettings.PromptCtx = nil
	}

	settings.HookTemplateDir = getTargetTemplateDir(
		settings.InstallDir,
		args.TemplateDir,
		args.UseCoreHooksPath,
		args.NonInteractive,
		args.DryRun,
		uiSettings.PromptCtx)

	installBinaries(
		settings.InstallDir,
		settings.CloneDir,
		settings.TempDir,
		args.InternalBinaries,
		args.DryRun)

	setupHookTemplates(
		settings.HookTemplateDir,
		settings.CloneDir,
		settings.TempDir,
		args.OnlyServerHooks,
		args.NonInteractive,
		args.DryRun,
		uiSettings.PromptCtx)

	if !args.InternalAutoUpdate {
		setupAutomaticUpdate(args.NonInteractive, args.DryRun, uiSettings.PromptCtx)
	}

	if !args.SkipInstallIntoExisting {
		if args.SingleInstall {

			installGitHooksIntoRepo(
				getCurrentGitDir(settings.Cwd),
				settings.TempDir,
				args.NonInteractive,
				args.DryRun,
				uiSettings)

		}
		// else {
		// 	// if !args.InternalAutoUpdate {
		// 	// 	//installGitHooksIntoExistingRepos()
		// 	// }
		// 	//installGitHooksIntoRegisteredRepos()
		// }
	}

	if !args.InternalAutoUpdate && !args.NonInteractive && !args.SingleInstall {
		setupSharedHookRepositories()
	}

	thankYou()
}

func runInstall(cmd *cobra.Command, auxArgs []string) {

	log.DebugF("Arguments: %+v", args)
	validateArgs(cmd, &args)

	settings, uiSettings := setMainVariables(&args)

	if !args.DryRun {
		setInstallDir(settings.InstallDir)
	}

	if !args.InternalPostUpdate {
		if isDispatched := prepareDispatch(&settings, &args); isDispatched {
			return
		}
	}

	runUpdate(&settings, &uiSettings, &args)
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
