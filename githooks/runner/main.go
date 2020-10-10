// Base Git hook template from https://github.com/rycus86/githooks
//
// It allows you to have a .githooks folder per-project that contains
// its hooks to execute on various Git triggers.
//
// Legacy version number. Not used anymore, but old installs read it.
// Version: 9912.310000-000000

package main

import (
	"fmt"
	"os"
	"path/filepath"
	path "path/filepath"
	cm "rycus86/githooks/common"
	hooks "rycus86/githooks/githooks"
	strs "rycus86/githooks/strings"
	"strings"

	"github.com/mitchellh/go-homedir"
)

var log cm.ILogContext

// HookSettings defines hooks related settings for this run.
type HookSettings struct {
	args           []string       // Rest arguments.
	git            *cm.GitContext // Git context to execute commands (working dir is this repository)
	repositoryPath string         // Repository path.
	gitDir         string         // Git directory.
	installDir     string         // Install directory.

	hookPath string // Absolute path of the hook executing this runner.
	hookName string // Name of the hook.
	hookDir  string // Directory of the hook.

	isTrusted bool // If the repository is a trusted repository.
}

// UISettings defines user interface settings made by the user over prompts.
type UISettings struct {

	// A prompt context which enables showing a prompt.
	promptCtx cm.IPromptContext

	// The user accepts all newly/changed hooks as trusted.
	acceptAllChanges bool

	// All hooks which were newly trusted and need to be recorded back
	newlyTrustedHooks []hooks.ChecksumData

	// All hooks which were newly trusted and need to be recored back
	newlyDisabledHooks []hooks.ChecksumResult
}

func (s HookSettings) toString() string {
	return strs.Fmt("\n- Args: '%q'\n"+
		"- Repo Path: '%s'\n"+
		"- Git Dir: '%s'\n"+
		"- Install Dir: '%s'\n"+
		"- Hook Path: '%s'\n"+
		"- Trusted: '%v'",
		s.args, s.repositoryPath, s.gitDir, s.installDir, s.hookPath, s.isTrusted)
}

func createLog() {
	var err error
	log, err = cm.CreateLogContext()
	cm.AssertOrPanic(err == nil, "Could not create log")
}

func setMainVariables(repoPath string) (HookSettings, UISettings) {

	cm.PanicIf(
		len(os.Args) <= 1,
		"No arguments given! -> Abort")

	git := cm.Git() // Current git context, in current working dir.
	gitDir, err := git.Get("rev-parse", "--git-common-dir")
	cm.AssertNoErrorPanic(err, "Could not get git directory.")
	gitDir, err = path.Abs(gitDir)
	cm.AssertNoErrorPanic(err, "Could not get git directory.")

	hookPath, err := path.Abs(os.Args[1])
	cm.AssertNoErrorPanicF(err, "Could not abs. path from '%s'.",
		os.Args[1])

	exists, _ := cm.PathExists(hookPath)
	cm.DebugAssert(exists, "Hook path does not exist")

	installDir := getInstallDir(git)

	dialogTool, err := hooks.GetToolScript(installDir, "dialog")
	log.AssertNoErrorWarnF(err, "Could not get status of 'dialog' tool")

	promptCtx, err := cm.CreatePromptContext(log, git, dialogTool)
	log.AssertNoErrorWarnF(err, "Could not get status of 'dialog' tool")

	isTrusted, err := hooks.IsRepoTrusted(git, promptCtx, repoPath, true)
	log.AssertNoErrorWarn(err, "Could not get trust settings.")

	s := HookSettings{
		args:           os.Args[2:],
		git:            git,
		repositoryPath: repoPath,
		gitDir:         gitDir,
		installDir:     installDir,
		hookPath:       hookPath,
		hookName:       path.Base(hookPath),
		hookDir:        path.Dir(hookPath),
		isTrusted:      isTrusted}

	log.LogDebugF(s.toString())

	return s, UISettings{acceptAllChanges: false, promptCtx: promptCtx}
}

func getInstallDir(git *cm.GitContext) string {
	installDir := hooks.GetInstallDir(git)

	setDefault := func() {
		usr, err := homedir.Dir()
		cm.AssertNoErrorPanic(err, "Could not get home directory.")
		installDir = filepath.Join(usr, ".githooks")
	}

	if installDir == "" {
		setDefault()
	} else if exists, err := cm.PathExists(installDir); !exists {

		log.AssertNoErrorWarn(err,
			"Could not check path '%s'", installDir)
		log.LogWarnF(
			"Githooks installation is corrupt!\n"+
				"Install directory at '%s' is missing.",
			installDir)

		setDefault()

		log.LogWarnF(
			"Falling back to default directory at '%s'.\n"+
				"Please run the Githooks install script again to fix it.",
			installDir)
	}

	log.LogDebug(strs.Fmt("Install dir set to: '%s'.", installDir))
	return installDir
}

func assertRegistered(git *cm.GitContext, installDir string, gitDir string) {

	if !git.IsConfigSet("githooks.registered", cm.LocalScope) &&
		!git.IsConfigSet("core.hooksPath", cm.Traverse) {

		log.LogDebugF("Register repo '%s'", gitDir)

		err := hooks.RegisterRepo(gitDir, installDir, true)
		if err != nil {
			log.LogWarn("Could not register repo '%s'.", gitDir)
		} else {
			git.SetConfig("githooks.registered", "true", cm.LocalScope)
		}

	} else {
		log.LogDebug(
			"Repository already registered or using 'core.hooksPath'.")
	}
}

func executeLFSHooks(settings HookSettings) {

	if !strs.Includes(hooks.LFSHookNames[:], settings.hookName) {
		return
	}

	lfsIsAvailable := hooks.IsLFSAvailable()

	lfsIsRequired, err := cm.PathExists(filepath.Join(
		settings.repositoryPath, ".githooks", ".lfs-required"))
	log.AssertNoErrorWarnF(err, "Could not check path.")

	if lfsIsAvailable {
		log.LogDebug("Excuting LFS Hook")

		err := settings.git.CheckPiped(
			append(
				[]string{"lfs", settings.hookName},
				settings.args...,
			)...)

		log.AssertNoErrorFatal(err, "Execution of LFS Hook failed.")

	} else {
		log.LogDebug("Git LFS not available")
		log.FatalIf(lfsIsRequired,
			"This repository requires Git LFS, but 'git-lfs' was",
			"not found on your PATH. If you no longer want to use",
			"Git LFS, remove the '.githooks/.lfs-required' file.",
		)
	}
}

func executeHook(settings HookSettings, hook hooks.Hook) {
	log.LogDebugF("Executing hook: '%s'.", hook.Path)
}

func executeOldHooks(settings HookSettings,
	uiSettings UISettings,
	ingores hooks.IgnorePatterns,
	checksums hooks.ChecksumStore) {

	hookName := settings.hookName + ".replaced.githooks"
	// Make it relative to git directory
	// e.g. 'hooks/pre-commit.replaced.githooks'
	hook := hooks.Hook{Path: filepath.Join(settings.hookDir, hookName), RunCmd: nil}

	exists, err := cm.PathExists(hook.Path)
	log.AssertNoErrorWarnF(err, "Could not check path '%s'", hook.Path)
	if !exists {
		log.LogDebugF("Old hook:\n'%s'\ndoes not exist. -> Skip!", hook.Path)
		return
	}

	// @todo Introduce namespacing here!
	ignored, byUser := ingores.IsIgnored(hookName)
	if ignored && byUser {
		// Old hook can only be ignored by user patterns!
		log.LogDebugF("Old local hook '%s' is ignored by user -> Skip.", hook.Path)
		return
	}

	if !settings.isTrusted &&
		!executeSafetyChecks(settings, uiSettings, &checksums, hook.Path) {
		return
	}

	hook.RunCmd, err = hooks.GetHookRunCmd(hook.Path)
	if !log.AssertNoErrorWarnF(err, "Could not detect runner for hook\n'%s'\n-> Skip it!",
		hook.Path) {
		return
	}

	executeHook(settings, hook)
}

func executeSafetyChecks(settings HookSettings,
	uiSettings UISettings,
	checksums *hooks.ChecksumStore,
	hookPath string) (runHook bool) {

	trusted, sha1, err := checksums.IsTrusted(hookPath)
	if !log.AssertNoErrorWarnF(err,
		"Could not check trust status '%s'.", hookPath) {
		return
	}

	if !trusted {
		mess := strs.Fmt("New or changed hook found:\n'%s'", hookPath)

		if !uiSettings.acceptAllChanges {

			question := mess + "\nDo you accept the changes?"

			answer, err := uiSettings.promptCtx.ShowPrompt(question,
				"(Yes, all, no, disable)",
				"Y/a/n/d",
				"Yes", "All", "No", "Disable")

			if !log.AssertNoErrorWarn(err,
				"Could not show trust prompt.") {
				return
			}

			answer = strings.ToLower(answer)

			switch strings.ToLower(answer) {
			case "a":
				uiSettings.acceptAllChanges = true
				fallthrough
			case "y":
				checksums.AddChecksum(sha1, hookPath)
				runHook = true
			case "d":
				uiSettings.newlyDisabledHooks = append(
					uiSettings.newlyDisabledHooks, hooks.ChecksumResult{SHA1: sha1, Path: hookPath})
				fallthrough
			case "n":
				fallthrough
			default:
				// no changes
			}
		} else {
			log.LogInfo(mess, "-> Already accepted.")
		}
	}

	return
}

func exportStagedFiles(settings HookSettings) {
	if strs.Includes(hooks.StagedFilesHookNames[:], settings.hookName) {

		files, err := hooks.GetStagedFiles(settings.git)

		if len(files) != 0 {
			log.LogDebugF("Exporting staged files:\n- %s",
				strings.ReplaceAll(files, "\n", "\n- "))
		}

		if err != nil {
			log.LogWarn("Could not export staged files.")
		} else {

			cm.DebugAssertF(
				func() bool {
					_, exists := os.LookupEnv(hooks.EnvVariableStagedFiles)
					return !exists
				}(),
				"Env. variable '%s' already defined.", hooks.EnvVariableStagedFiles)

			os.Setenv(hooks.EnvVariableStagedFiles, files)
		}

	}
}

func getIgnorePatterns(settings HookSettings) hooks.IgnorePatterns {

	var patt hooks.IgnorePatterns
	var err error

	patt.Worktree, err = hooks.GetHookIgnorePatternsWorktree(
		settings.repositoryPath,
		settings.hookName)

	log.AssertNoErrorWarn(err, "Could not get hook ignore patterns.")
	if patt.Worktree != nil {
		log.LogDebugF("Worktree ignore patterns: '%q'.", patt.Worktree.Patterns)
	} else {
		log.LogDebug("Worktree ignore patterns: 'none' ")
	}

	patt.User, err = hooks.GetHookIgnorePatterns(settings.gitDir)

	log.AssertNoErrorWarn(err, "Could not get user ignore patterns.")
	if patt.User != nil {
		log.LogDebugF("User ignore patterns: '%v'.", patt.User.Patterns)
	} else {
		log.LogDebug("User ignore patterns: 'none' ")
	}

	return patt
}

func getLocalChecksumStore(settings HookSettings) hooks.ChecksumStore {
	localChecksums := filepath.Join(settings.gitDir, ".githooks.checksum")
	store, err := hooks.NewChecksumStore(localChecksums, false)
	log.AssertNoErrorWarnF(err, "Could not init checksum store in '%s'.", localChecksums)
	log.LogDebugF("%s", store.Summary())

	return store
}

func storePendingData(settings HookSettings, uiSettings UISettings) {

}

func main() {

	_, err := os.OpenFile("/dev/tty", os.O_RDONLY, 0)
	if err != nil {
		fmt.Print("wups")
		os.Exit(1)
	}

	createLog()

	startTime := cm.GetStartTime()
	exitCode := 0

	defer func() { os.Exit(exitCode) }()
	defer func() {
		log.LogDebugF("Runner execution time: '%v'.",
			cm.GetDuration(startTime))
	}()

	cwd, err := os.Getwd()
	cm.AssertNoErrorPanic(err, "Could not get current working dir.")

	// Handle all panics and report the error
	defer func() {
		r := recover()
		if r == nil {
			return
		}

		var message string
		withTrace := false

		switch v := r.(type) {
		case cm.GithooksFailure:
			message = "Fatal error -> Abort."
		case error:
			info, e := hooks.GetBugReportingInfo(cwd)
			v = cm.CombineErrors(v, e)
			message = v.Error() + "\n" + info
			withTrace = true

		default:
			info, e := hooks.GetBugReportingInfo(cwd)
			e = cm.CombineErrors(cm.Error("Panic 💩: Unknown error"), e)
			message = e.Error() + "\n" + info
			withTrace = true
		}

		if log != nil && withTrace {
			log.LogErrorWithStacktrace(message)
		} else if log != nil && !withTrace {
			log.LogError(message)
		} else {
			os.Stderr.WriteString(err.Error() + "\n")
		}

		exitCode = 1
	}()

	settings, uiSettings := setMainVariables(cwd)
	defer storePendingData(settings, uiSettings)

	assertRegistered(settings.git, settings.installDir, settings.gitDir)

	checksums := getLocalChecksumStore(settings)
	ignores := getIgnorePatterns(settings)

	if hooks.IsGithooksDisabled(settings.git) {
		executeLFSHooks(settings)
		executeOldHooks(settings, uiSettings, ignores, checksums)
		return
	}

	exportStagedFiles(settings)
	executeLFSHooks(settings)
	executeOldHooks(settings, uiSettings, ignores, checksums)

	//executeHooks(settings, ignores)

	uiSettings.promptCtx.Close()
	log.LogDebug("All done.\n")
}
