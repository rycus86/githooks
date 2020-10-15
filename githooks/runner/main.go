// Base Git hook template from https://github.com/rycus86/githooks
//
// It allows you to have a .githooks (see `hooks.HookDirName`)
// folder per-project that contains
// its hooks to execute on various Git triggers.
//
// Legacy version number. Not used anymore, but old installs read it.
// Version: 9912.310000-000000

package main

import (
	"os"
	"path/filepath"
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"
	hooks "rycus86/githooks/githooks"
	strs "rycus86/githooks/strings"
	"strings"

	"github.com/mitchellh/go-homedir"
)

var log cm.ILogContext

func main() {
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
		logBatches("Local Hooks", hooks.LocalHooks)
		logBatches("Repo Shared Hooks", hooks.RepoSharedHooks)
		logBatches("Local Shared Hooks", hooks.LocalSharedHooks)
		logBatches("Global Shared Hooks", hooks.GlobalSharedHooks)
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

	gitx := git.Ctx() // Current git context, in current working dir.
	gitDir, err := gitx.Get("rev-parse", "--git-common-dir")
	cm.AssertNoErrorPanic(err, "Could not get git directory.")
	gitDir, err = filepath.Abs(gitDir)
	cm.AssertNoErrorPanic(err, "Could not get git directory.")

	hookPath, err := filepath.Abs(os.Args[1])
	cm.AssertNoErrorPanicF(err, "Could not abs. path from '%s'.",
		os.Args[1])

	exists, _ := cm.IsPathExisting(hookPath)
	cm.DebugAssert(exists, "Hook path does not exist")

	installDir := getInstallDir(gitx)

	dialogTool, err := hooks.GetToolScript(installDir, "dialog")
	log.AssertNoErrorWarnF(err, "Could not get status of 'dialog' tool")

	promptCtx, err := cm.CreatePromptContext(log, gitx, dialogTool)
	log.AssertNoErrorWarnF(err, "Could not get prompt context.")

	isTrusted, err := hooks.IsRepoTrusted(gitx, promptCtx, repoPath, true)
	log.AssertNoErrorWarn(err, "Could not get trust settings.")

	failOnNonExistingHooks := gitx.GetConfig("githooks.failOnNonExistingSharedHooks", git.Traverse) == "true"

	s := HookSettings{
		Args:               os.Args[2:],
		Git:                gitx,
		RepositoryPath:     repoPath,
		RepositoryHooksDir: filepath.Join(repoPath, hooks.HookDirName),
		GitDir:             gitDir,
		InstallDir:         installDir,

		HookPath: hookPath,
		HookName: filepath.Base(hookPath),
		HookDir:  filepath.Dir(hookPath),

		IsTrusted: isTrusted,

		FailOnNonExistingSharedHooks: failOnNonExistingHooks}

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

func getInstallDir(git *git.Context) string {
	installDir := hooks.GetInstallDir(git)

	setDefault := func() {
		usr, err := homedir.Dir()
		cm.AssertNoErrorPanic(err, "Could not get home directory.")
		installDir = filepath.Join(usr, hooks.HookDirName)
	}

	if installDir == "" {
		setDefault()
	} else if exists, err := cm.IsPathExisting(installDir); !exists {

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

func assertRegistered(gitx *git.Context, installDir string, gitDir string) {

	if !gitx.IsConfigSet("githooks.registered", git.LocalScope) &&
		!gitx.IsConfigSet("core.hooksPath", git.Traverse) {

		log.LogDebugF("Register repo '%s'", gitDir)

		err := hooks.RegisterRepo(gitDir, installDir, true)
		if err != nil {
			log.LogWarn("Could not register repo '%s'.", gitDir)
		} else {
			gitx.SetConfig("githooks.registered", "true", git.LocalScope)
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

	lfsIsRequired, err := cm.IsPathExisting(filepath.Join(
		settings.RepositoryPath, hooks.HookDirName, ".lfs-required"))
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
			strs.Fmt("Git LFS, remove the '%s/.lfs-required' file.",
				hooks.HookDirName),
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

	exists, err := cm.IsPathExisting(hook.Path)
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

	var allAddedShared = make([]string, 0)
	h.RepoSharedHooks = geRepoSharedHooks(settings, uiSettings, ignores, checksums, &allAddedShared)
	h.LocalSharedHooks = getConfigSharedHooks(settings, uiSettings, ignores, checksums, &allAddedShared, hooks.SharedHookEnum.Local)
	h.GlobalSharedHooks = getConfigSharedHooks(settings, uiSettings, ignores, checksums, &allAddedShared, hooks.SharedHookEnum.Global)
	return
}

func geRepoSharedHooks(
	settings *HookSettings,
	uiSettings *UISettings,
	ignores *hooks.IgnorePatterns,
	checksums *hooks.ChecksumStore,
	allAddedHooks *[]string) (hs hooks.HookPrioList) {

	sharedHooks, err := hooks.LoadRepoSharedHooks(settings.InstallDir, settings.RepositoryHooksDir)

	if err != nil {
		log.LogErrorOrFatalF(settings.FailOnNonExistingSharedHooks, err,
			"Repository shared hooks are demanded but failed "+
				"to parse the file:\n'%s'",
			hooks.GetRepoSharedFile(settings.RepositoryHooksDir))
	}

	for _, sharedHook := range sharedHooks {
		if checkSharedHook(settings, sharedHook, allAddedHooks, hooks.SharedHookEnum.Repo) {
			hs = getHooksInShared(settings, uiSettings, sharedHook, ignores, checksums)
			log.LogDebugF("Collected hooks: '%q'", hs)
		}
	}
	return
}

func getConfigSharedHooks(
	settings *HookSettings,
	uiSettings *UISettings,
	ignores *hooks.IgnorePatterns,
	checksums *hooks.ChecksumStore,
	allAddedHooks *[]string,
	sharedType int) (hs hooks.HookPrioList) {

	var sharedHooks []hooks.SharedHook
	var err error

	if sharedType == hooks.SharedHookEnum.Local {
		sharedHooks, err = hooks.LoadConfigSharedHooks(settings.InstallDir, settings.Git, git.LocalScope)
	} else if sharedType == hooks.SharedHookEnum.Global {
		sharedHooks, err = hooks.LoadConfigSharedHooks(settings.InstallDir, settings.Git, git.GlobalScope)
	} else {
		cm.DebugAssertF(false, "Wrong shared type '%v'", sharedType)
	}

	if err != nil {
		log.LogErrorOrFatalF(settings.FailOnNonExistingSharedHooks,
			err,
			"Shared hooks are demanded but failed "+
				"to parse the %s config:\n'%s'",
			hooks.GetSharedHookTypeString(sharedType),
			hooks.SharedConfigName)
	}

	for _, sharedHook := range sharedHooks {
		if checkSharedHook(settings, sharedHook, allAddedHooks, sharedType) {
			hs = append(hs, getHooksInShared(settings, uiSettings, sharedHook, ignores, checksums)...)
			log.LogDebugF("Collected hooks: '%q'", hs)
		}
	}
	return
}

func checkSharedHook(settings *HookSettings, hook hooks.SharedHook, allAddedHooks *[]string, sharedType int) bool {

	if strs.Includes(*allAddedHooks, hook.RootDir) {
		log.LogWarnF(
			"Shared hooks entry:\n'%s'\n"+
				"is already listed and will be skipped.", hook.OriginalURL)

		return false
	}

	// Check that no local paths are in repository configured
	// shared hooks
	log.FatalIfF(sharedType == hooks.SharedHookEnum.Repo && hook.IsLocal,
		"Shared hooks in '%[1]s/.shared' contain a local path\n"+
			"'%[2]s'\n"+
			"which is forbidden.\n"+
			"\n"+
			"You can only have local paths in shared hooks defined\n"+
			"in the local or global Git configuration.\n"+
			"\n"+
			"You need to fix this by running\n"+
			"  $ git hooks shared add [--local|--global] '%[2]s'\n"+
			"and deleting it from the '.shared' file by\n"+
			"  $ git hooks shared remove --shared '%[2]s'",
		hooks.HookDirName, hook.OriginalURL)

	// Check if existing otherwise skip or fail...
	exists, err := cm.IsPathExisting(hook.RootDir)
	if !exists {

		mess := "Failed to execute shared hooks in:\n" +
			"'%s'\n"

		if hook.IsLocal {
			mess += "It does not exist."
		} else {
			mess += "It is not available. To fix, run:\n" +
				"$ git hooks shared update"
		}

		if !settings.FailOnNonExistingSharedHooks {
			mess += "\nContinuing..."
		}

		log.LogErrorOrFatalF(settings.FailOnNonExistingSharedHooks, err, mess, hook.OriginalURL)
		return false
	}

	// If cloned check that the remote url
	// is the same as the specified
	// Note: GIT_DIR might be set (?bug?) (actually the case for post-checkout hook)
	// which means we really need a `-f` to sepcify the actual config!
	if hook.IsCloned {
		url := git.CtxC(hook.RootDir).GetConfig(
			"remote.origin.url", git.LocalScope)

		if url != hook.URL {
			mess := "Failed to execute shared hooks in '%s'\n" +
				"The remote URL '%s' is different.\n" +
				"To fix it, run:\n" +
				"  $ git hooks shared purge\n" +
				"  $ git hooks shared update"

			if !settings.FailOnNonExistingSharedHooks {
				mess += "\nContinuing..."
			}

			log.LogErrorOrFatalF(settings.FailOnNonExistingSharedHooks,
				nil, mess, hook.OriginalURL, url)
			return false
		}
	}

	return true
}

func createHook(settings *HookSettings,
	uiSettings *UISettings,
	hookPath string,
	ingores *hooks.IgnorePatterns,
	checksums *hooks.ChecksumStore) (hooks.Hook, bool) {
	// Check if trusted
	if !settings.IsTrusted &&
		!executeSafetyChecks(settings, uiSettings, checksums, hookPath) {
		log.LogDebugF("Hook '%s' skipped", hookPath)
		return hooks.Hook{}, false
	}

	runCmd, err := hooks.GetHookRunCmd(hookPath)
	log.AssertNoErrorFatalF(err, "Could not detect runner for hook\n'%s'", hookPath)

	return hooks.Hook{Path: hookPath, RunCmd: runCmd}, true
}

func getHooksIn(settings *HookSettings,
	uiSettings *UISettings,
	path string,
	ignores *hooks.IgnorePatterns,
	checksums *hooks.ChecksumStore) (batches hooks.HookPrioList) {

	log.LogDebugF("Getting hooks in '%s'", path)

	dirOrFile := filepath.Join(path, settings.HookName)
	// Collect all in e.g. `path/pre-commit/*`
	if cm.IsDirectory(dirOrFile) {
		log.LogDebugF("Search in dir: '%s'", dirOrFile)

		hookFiles, err := cm.GetFiles(dirOrFile,
			func(path string, _ os.FileInfo) bool {
				ignored, _ := ignores.IsIgnored(path)
				return !ignored
			})
		log.AssertNoErrorWarnF(err, "Errors while walking '%s'", path)

		// @todo make a priority list for executing all batches in parallel
		// First good solution: all sequential
		for _, hookFile := range hookFiles {

			hook, use := createHook(settings, uiSettings, hookFile, ignores, checksums)
			if !use {
				continue
			}

			batch := []hooks.Hook{hook}
			batches = append(batches, batch)
		}

	} else if cm.IsFile(dirOrFile) { // Check hook in `path/pre-commit`

		log.LogDebugF("Use file: '%s'", dirOrFile)

		hook, use := createHook(settings, uiSettings, dirOrFile, ignores, checksums)
		if use {
			batch := []hooks.Hook{hook}
			batches = append(batches, batch)
		}
	}

	log.LogDebugF("Got hooks: '%q'", batches)
	return
}

func getHooksInShared(settings *HookSettings,
	uiSettings *UISettings,
	hook hooks.SharedHook,
	ignores *hooks.IgnorePatterns,
	checksums *hooks.ChecksumStore) hooks.HookPrioList {
	return getHooksIn(settings, uiSettings, hook.RootDir, ignores, checksums)
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
