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
		handleError(cwd, r)
		exitCode = 1
	}()

	settings, uiSettings := setMainVariables(cwd)
	defer storePendingData(settings, uiSettings)

	assertRegistered(settings.Git, settings.InstallDir, settings.GitDir)

	checksums := getLocalChecksumStore(settings)
	ignores := getIgnorePatterns(settings)

	if hooks.IsGithooksDisabled(settings.Git) {
		executeLFSHooks(settings)
		executeOldHooks(settings, uiSettings, ignores, checksums)
		return
	}

	exportStagedFiles(settings)
	executeLFSHooks(settings)
	executeOldHooks(settings, uiSettings, ignores, checksums)

	// executeSharedHooks(settings, uiSettings, ignores, checksums)

	hooks := collectHooks(settings, uiSettings, ignores, checksums)

	if cm.IsDebug {
		logBatches("Global Shared Hooks", hooks.GlobalSharedHooks)
		logBatches("Local Shared Hooks:", hooks.LocalSharedHooks)
		logBatches("Local Hooks", hooks.LocalHooks)
	}

	uiSettings.PromptCtx.Close()
	log.LogDebug("All done.\n")
}

func createLog() {
	var err error
	log, err = cm.CreateLogContext()
	cm.AssertOrPanic(err == nil, "Could not create log")
}

func setMainVariables(repoPath string) (*HookSettings, *UISettings) {

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

	exists, _ := cm.IsPathExist(hookPath)
	cm.DebugAssert(exists, "Hook path does not exist")

	installDir := getInstallDir(git)

	dialogTool, err := hooks.GetToolScript(installDir, "dialog")
	log.AssertNoErrorWarnF(err, "Could not get status of 'dialog' tool")

	promptCtx, err := cm.CreatePromptContext(log, git, dialogTool)
	log.AssertNoErrorWarnF(err, "Could not get prompt context.")

	isTrusted, err := hooks.IsRepoTrusted(git, promptCtx, repoPath, true)
	log.AssertNoErrorWarn(err, "Could not get trust settings.")

	s := HookSettings{
		Args:               os.Args[2:],
		Git:                git,
		RepositoryPath:     repoPath,
		RepositoryHooksDir: filepath.Join(repoPath, ".githooks"),
		GitDir:             gitDir,
		InstallDir:         installDir,
		HookPath:           hookPath,
		HookName:           path.Base(hookPath),
		HookDir:            path.Dir(hookPath),
		IsTrusted:          isTrusted}

	log.LogDebugF(s.toString())

	return &s, &UISettings{AcceptAllChanges: false, PromptCtx: promptCtx}
}

func getIgnorePatterns(settings *HookSettings) *hooks.IgnorePatterns {

	var patt hooks.IgnorePatterns
	var err error

	patt.Worktree, err = hooks.GetHookIgnorePatternsWorktree(
		settings.RepositoryPath,
		settings.HookName)

	log.AssertNoErrorWarn(err, "Could not get hook ignore patterns.")
	if patt.Worktree != nil {
		log.LogDebugF("Worktree ignore patterns: '%q'.", patt.Worktree.Patterns)
	} else {
		log.LogDebug("Worktree ignore patterns: 'none' ")
	}

	patt.User, err = hooks.GetHookIgnorePatterns(settings.GitDir)

	log.AssertNoErrorWarn(err, "Could not get user ignore patterns.")
	if patt.User != nil {
		log.LogDebugF("User ignore patterns: '%v'.", patt.User.Patterns)
	} else {
		log.LogDebug("User ignore patterns: 'none' ")
	}

	return &patt
}

func getLocalChecksumStore(settings *HookSettings) *hooks.ChecksumStore {
	localChecksums := filepath.Join(settings.GitDir, ".githooks.checksum")
	store, err := hooks.NewChecksumStore(localChecksums, false)
	log.AssertNoErrorWarnF(err, "Could not init checksum store in '%s'.", localChecksums)
	log.LogDebugF("%s", store.Summary())

	return &store
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
	} else if exists, err := cm.IsPathExist(installDir); !exists {

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

func exportStagedFiles(settings *HookSettings) {
	if strs.Includes(hooks.StagedFilesHookNames[:], settings.HookName) {

		files, err := hooks.GetStagedFiles(settings.Git)

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

func executeLFSHooks(settings *HookSettings) {

	if !strs.Includes(hooks.LFSHookNames[:], settings.HookName) {
		return
	}

	lfsIsAvailable := hooks.IsLFSAvailable()

	lfsIsRequired, err := cm.IsPathExist(filepath.Join(
		settings.RepositoryPath, ".githooks", ".lfs-required"))
	log.AssertNoErrorWarnF(err, "Could not check path.")

	if lfsIsAvailable {
		log.LogDebug("Excuting LFS Hook")

		err := settings.Git.CheckPiped(
			append(
				[]string{"lfs", settings.HookName},
				settings.Args...,
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

func executeOldHooks(settings *HookSettings,
	uiSettings *UISettings,
	ingores *hooks.IgnorePatterns,
	checksums *hooks.ChecksumStore) {

	hookName := settings.HookName + ".replaced.githook"
	// Make it relative to git directory
	// e.g. 'hooks/pre-commit.replaced.githook'
	hook := hooks.Hook{Path: filepath.Join(settings.HookDir, hookName), RunCmd: nil}

	exists, err := cm.IsPathExist(hook.Path)
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

	if !settings.IsTrusted &&
		!executeSafetyChecks(settings, uiSettings, checksums, hook.Path) {
		log.LogDebugF("Hook '%s' skipped", hook.Path)
		return
	}

	hook.RunCmd, err = hooks.GetHookRunCmd(hook.Path)
	log.AssertNoErrorFatalF(err, "Could not detect runner for hook\n'%s'", hook.Path)

	err = executeHook(settings, hook)
	log.AssertNoErrorFatalF(err, "Hook launch failed: '%q'.", hook)
}

func collectHooks(
	settings *HookSettings,
	uiSettings *UISettings,
	ignores *hooks.IgnorePatterns,
	checksums *hooks.ChecksumStore) (h hooks.Hooks) {

	// Local hooks in repository
	h.LocalHooks = getHooksIn(settings, uiSettings, settings.RepositoryHooksDir, ignores, checksums)

	return
}

func getSharedHooks(settings *HookSettings,
	uiSettings *UISettings,
	ingores *hooks.IgnorePatterns,
	checksums *hooks.ChecksumStore) {

}

func getHooksIn(settings *HookSettings,
	uiSettings *UISettings,
	path string,
	ingores *hooks.IgnorePatterns,
	checksums *hooks.ChecksumStore) (batches hooks.HookPrioList) {

	dir := filepath.Join(path, settings.HookName)
	exists, err := cm.IsPathExist(dir)
	log.AssertNoErrorWarnF(err, "Error in path check '%s'", dir)

	if exists {
		hookFiles, err := cm.GetFiles(dir,
			func(path string, _ os.FileInfo) bool {
				ignored, _ := ingores.IsIgnored(path)
				return !ignored
			})
		log.AssertNoErrorWarnF(err, "Errors while walking '%s'", path)

		// @todo make a priority list for executing all batches in parallel
		// First good solution: all sequential
		for _, path := range hookFiles {

			// Check if trusted
			if !settings.IsTrusted &&
				!executeSafetyChecks(settings, uiSettings, checksums, path) {
				log.LogDebugF("Hook '%s' skipped", path)
				continue
			}

			runCmd, err := hooks.GetHookRunCmd(path)
			log.AssertNoErrorFatalF(err, "Could not detect runner for hook\n'%s'", path)

			batch := []hooks.Hook{hooks.Hook{Path: path, RunCmd: runCmd}}
			batches = append(batches, batch)
		}
	}

	return
}

func logBatches(title string, hooks hooks.HookPrioList) {
	var l string

	if hooks == nil {
		log.LogInfoF("%s: none", title)
	} else {
		for bIdx, batch := range hooks {
			l += strs.Fmt(" Batch: %v\n", bIdx)
			for _, h := range batch {
				l += strs.Fmt("  - '%s'\n", h.Path)
			}
		}
		log.LogInfoF("%s :\n%s", title, l)
	}
}

func executeSafetyChecks(settings *HookSettings,
	uiSettings *UISettings,
	checksums *hooks.ChecksumStore,
	hookPath string) (runHook bool) {

	trusted, sha1, err := checksums.IsTrusted(hookPath)
	if !log.AssertNoErrorWarnF(err,
		"Could not check trust status '%s'.", hookPath) {
		return
	}

	if trusted {
		runHook = true
	} else {
		mess := strs.Fmt("New or changed hook found:\n'%s'", hookPath)

		acceptHook := uiSettings.AcceptAllChanges

		if !acceptHook {

			question := mess + "\nDo you accept the changes?"

			answer, err := uiSettings.PromptCtx.ShowPrompt(question,
				"(Yes, all, no, disable)",
				"Y/a/n/d",
				"Yes", "All", "No", "Disable")

			if !log.AssertNoErrorWarn(err,
				"Could not show trust prompt.") {
				return
			}

			answer = strings.ToLower(answer)

			switch answer {
			case "a":
				uiSettings.AcceptAllChanges = true
				fallthrough
			case "y":
				acceptHook = true
				runHook = true
			case "d":
				log.LogInfoF("-> Adding hook\n'%s'\nto disabled list.", hookPath)
				uiSettings.AppendDisabledHook(hooks.ChecksumResult{SHA1: sha1, Path: hookPath})
			default:
				// Don't run hook ...
			}
		} else {
			log.LogInfo("-> Already accepted.")
			runHook = true
		}

		if acceptHook {
			checksums.AddChecksum(sha1, hookPath)
		}
	}

	return
}

func executeHook(settings *HookSettings, hook hooks.Hook) error {
	log.LogDebugF("Executing hook: '%s'.", hook.Path)
	err := cm.RunExecutable(settings.Git, &hook, true)
	return err
}

func storePendingData(settings *HookSettings, uiSettings *UISettings) {

}

func handleError(cwd string, r interface{}) {
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
		os.Stderr.WriteString(message + "\n")
	}
}
