//go:generate go run -mod=vendor ../../tools/generate-version.go
package main

import (
	"os"
	"path"
	"path/filepath"
	"runtime"
	"rycus86/githooks/build"
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"
	"rycus86/githooks/hooks"
	"rycus86/githooks/prompt"
	strs "rycus86/githooks/strings"
	"rycus86/githooks/updates"
	"strconv"
	"strings"
	"time"

	"github.com/mitchellh/go-homedir"
	"github.com/pbenner/threadpool"
)

var log cm.ILogContext

func main() {

	createLog()

	log.DebugF("Githooks Runner [version: %s]", build.BuildVersion)

	startTime := cm.GetStartTime()
	exitCode := 0

	defer func() { os.Exit(exitCode) }()
	defer func() {
		log.DebugF("Runner execution time: '%v'.",
			cm.GetDuration(startTime))
	}()

	cwd, err := os.Getwd()
	cm.AssertNoErrorPanic(err, "Could not get current working dir.")
	cwd = filepath.ToSlash(cwd)

	// Handle all panics and report the error
	defer func() {
		r := recover()
		if hooks.HandleCLIErrors(r, cwd, log) {
			exitCode = 1
		}
	}()

	settings, uiSettings := setMainVariables(cwd)
	assertRegistered(settings.GitX, settings.InstallDir)

	checksums, err := hooks.GetChecksumStorage(settings.GitX, settings.GitDirWorktree)
	log.AssertNoErrorF(err, "Errors while loading checksum store.")
	log.DebugF("%s", checksums.Summary())

	ignores, err := hooks.GetIgnorePatterns(
		settings.RepositoryHooksDir,
		settings.GitDirWorktree,
		[]string{settings.HookName})
	log.AssertNoErrorF(err, "Errors while loading ignore patterns.")
	log.DebugF("HooksDir ignore patterns: '%+v'.", ignores.HooksDir)
	log.DebugF("User ignore patterns: '%+v'.", ignores.User)

	defer storePendingData(&settings, &uiSettings, &ignores, &checksums)

	if hooks.IsGithooksDisabled(settings.GitX, true) {
		executeLFSHooks(&settings)
		executeOldHook(&settings, &uiSettings, &ignores, &checksums)

		return
	}

	exportStagedFiles(&settings)
	updateGithooks(&settings, &uiSettings)
	executeLFSHooks(&settings)
	executeOldHook(&settings, &uiSettings, &ignores, &checksums)

	hooks := collectHooks(&settings, &uiSettings, &ignores, &checksums)

	if cm.IsDebug {
		logBatches("Local Hooks", hooks.LocalHooks)
		logBatches("Repo Shared Hooks", hooks.RepoSharedHooks)
		logBatches("Local Shared Hooks", hooks.LocalSharedHooks)
		logBatches("Global Shared Hooks", hooks.GlobalSharedHooks)
	}

	executeHooks(&settings, &hooks)

	uiSettings.PromptCtx.Close()
	log.Debug("All done.\n")
}

func createLog() {
	var err error
	// Its good to output everythin to stderr since git
	// might read stdin for certain hooks.
	// Either do redirection (which needs to be bombproof)
	// or just use stderr.
	log, err = cm.CreateLogContext(true)
	cm.AssertOrPanic(err == nil, "Could not create log")
}

func setMainVariables(repoPath string) (HookSettings, UISettings) {

	cm.PanicIf(
		len(os.Args) <= 1,
		"No arguments given! -> Abort")

	// General execution context, in currenct working dir.
	execx := cm.ExecContext{}

	// Current git context, in current working dir.
	gitx := git.Ctx()

	gitDir, err := gitx.GetGitDirWorktree()
	cm.AssertNoErrorPanic(err, "Could not get git directory.")

	err = hooks.DeleteHookDirTemp(path.Join(gitDir, "hooks"))
	log.AssertNoErrorF(err, "Could not clean temporary directory in '%s/hooks'.", gitDir)

	hookPath, err := filepath.Abs(os.Args[1])
	cm.AssertNoErrorPanicF(err, "Could not abs. path from '%s'.",
		os.Args[1])
	hookPath = filepath.ToSlash(hookPath)

	installDir := getInstallDir()

	dialogTool, err := hooks.GetToolScript(installDir, "dialog")
	log.AssertNoErrorF(err, "Could not get status of 'dialog' tool.")
	if dialogTool != nil {
		log.DebugF("Use dialog tool '%s'", dialogTool.GetCommand())
	}

	promptCtx, err := prompt.CreateContext(log, &execx, dialogTool, true, false)
	log.AssertNoErrorF(err, "Prompt setup failed -> using fallback.")

	isTrusted, hasTrustFile := hooks.IsRepoTrusted(gitx, repoPath)
	if !isTrusted && hasTrustFile {
		isTrusted = showTrustRepoPrompt(gitx, promptCtx)
	}
	log.AssertNoError(err, "Could not get trust settings.")

	failOnNonExistingHooks := gitx.GetConfig(hooks.GitCK_FailOnNonExistingSharedHooks, git.Traverse) == "true"

	s := HookSettings{
		Args:               os.Args[2:],
		ExecX:              execx,
		GitX:               gitx,
		RepositoryDir:      repoPath,
		RepositoryHooksDir: path.Join(repoPath, hooks.HooksDirName),
		GitDirWorktree:     gitDir,
		InstallDir:         installDir,

		HookPath: hookPath,
		HookName: path.Base(hookPath),
		HookDir:  path.Dir(hookPath),

		IsRepoTrusted: isTrusted,

		FailOnNonExistingSharedHooks: failOnNonExistingHooks}

	log.DebugF(s.toString())

	return s, UISettings{AcceptAllChanges: false, PromptCtx: promptCtx}
}

func getInstallDir() string {
	installDir := hooks.GetInstallDir()

	setDefault := func() {
		usr, err := homedir.Dir()
		cm.AssertNoErrorPanic(err, "Could not get home directory.")
		usr = filepath.ToSlash(usr)
		installDir = path.Join(usr, hooks.HooksDirName)
	}

	if strs.IsEmpty(installDir) {
		setDefault()
	} else if exists, err := cm.IsPathExisting(installDir); !exists {

		log.AssertNoError(err,
			"Could not check path '%s'", installDir)
		log.WarnF(
			"Githooks installation is corrupt!\n"+
				"Install directory at '%s' is missing.",
			installDir)

		setDefault()

		log.WarnF(
			"Falling back to default directory at '%s'.\n"+
				"Please run the Githooks install script again to fix it.",
			installDir)
	}

	log.Debug(strs.Fmt("Install dir set to: '%s'.", installDir))

	return installDir
}

func assertRegistered(gitx *git.Context, installDir string) {

	if !gitx.IsConfigSet(hooks.GitCK_Registered, git.LocalScope) &&
		!gitx.IsConfigSet(git.GitCK_CoreHooksPath, git.Traverse) {

		gitDir, err := gitx.GetGitDirCommon()
		log.AssertNoErrorPanicF(err, "Could not get Git common dir.")

		log.DebugF("Register repo '%s'", gitDir)
		err = hooks.RegisterRepo(gitDir, installDir, true, false)
		log.AssertNoErrorF(err, "Could not register repo '%s'.", gitDir)

		err = hooks.MarkRepoRegistered(gitx)
		log.AssertNoErrorF(err, "Could not set register flag in repo '%s'.", gitDir)

	} else {
		log.Debug(
			"Repository already registered or using 'core.hooksPath'.")
	}
}

func showTrustRepoPrompt(gitx *git.Context, promptCtx prompt.IContext) (isTrusted bool) {
	question := "This repository wants you to trust all current and\n" +
		"future hooks without prompting.\n" +
		"Do you want to allow running every current and future hooks?"

	var answer string
	answer, err := promptCtx.ShowPromptOptions(question, "(yes, No)", "y/N", "Yes", "No")
	log.AssertNoErrorF(err, "Could not show prompt.")

	if err == nil && answer == "y" || answer == "Y" {
		err := hooks.SetTrustAllSetting(gitx, true, false)
		log.AssertNoErrorF(err, "Could not store trust setting.")
		isTrusted = true
	} else {
		err := hooks.SetTrustAllSetting(gitx, false, false)
		log.AssertNoErrorF(err, "Could not store trust setting.")
	}

	return
}

func exportStagedFiles(settings *HookSettings) {
	if strs.Includes(hooks.StagedFilesHookNames[:], settings.HookName) {

		files, err := hooks.GetStagedFiles(settings.GitX)

		if len(files) != 0 {
			log.DebugF("Exporting staged files:\n- %s",
				strings.ReplaceAll(files, "\n", "\n- "))
		}

		if err != nil {
			log.Warn("Could not export staged files.")
		} else {

			cm.DebugAssertF(
				func() bool {
					_, exists := os.LookupEnv(hooks.EnvVariableStagedFiles)
					return !exists // nolint:nlreturn
				}(),
				"Env. variable '%s' already defined.", hooks.EnvVariableStagedFiles)

			os.Setenv(hooks.EnvVariableStagedFiles, files)
		}

	}
}

func updateGithooks(settings *HookSettings, uiSettings *UISettings) {

	if !shouldRunUpdateCheck(settings) {
		return
	}

	updateAvailable, err := updates.RunUpdate(
		settings.InstallDir,
		updates.DefaultAcceptUpdateCallback(log, uiSettings.PromptCtx, false),
		&settings.ExecX,
		cm.UseStreams(nil, log.GetInfoWriter(), log.GetErrorWriter()))

	log.AssertNoErrorPanic(err, "Running update failed.")
	if updateAvailable {
		log.Info("Updates successfully dispatched.")
	} else {
		log.InfoF("Githooks is at the latest version '%s'",
			build.GetBuildVersion().String())
	}

	log.Info(
		"If you would like to disable auto-updates, run:",
		"  $ git hooks update disable")
}

func shouldRunUpdateCheck(settings *HookSettings) bool {
	if settings.HookName != "post-commit" {
		return false
	}

	enabled, _ := updates.GetAutomaticUpdateCheckSettings()
	if !enabled {
		return false
	}

	lastUpdateCheck, _, err := updates.GetUpdateCheckTimestamp()
	log.AssertNoErrorF(err, "Could get last update check time.")

	return time.Since(lastUpdateCheck).Hours() > 24.0 //nolint: gomnd
}

func executeLFSHooks(settings *HookSettings) {

	if !strs.Includes(hooks.LFSHookNames[:], settings.HookName) {
		return
	}

	lfsIsAvailable := git.IsLFSAvailable()
	lfsIsRequired := cm.IsFile(hooks.GetLFSRequiredFile(settings.RepositoryDir))

	if lfsIsAvailable {
		log.Debug("Excuting LFS Hook")

		err := settings.GitX.CheckPiped(
			append(
				[]string{"lfs", settings.HookName},
				settings.Args...,
			)...)

		log.AssertNoErrorPanic(err, "Execution of LFS Hook failed.")

	} else {
		log.Debug("Git LFS not available")
		log.PanicIf(lfsIsRequired,
			"This repository requires Git LFS, but 'git-lfs' was",
			"not found on your PATH. If you no longer want to use",
			strs.Fmt("Git LFS, remove the '%s' file.",
				hooks.GetLFSRequiredFileRel()),
		)
	}
}

func executeOldHook(settings *HookSettings,
	uiSettings *UISettings,
	ingores *hooks.RepoIgnorePatterns,
	checksums *hooks.ChecksumStore) {

	// e.g. 'hooks/pre-commit.replaced.githook's
	hookName := hooks.GetHookReplacementFileName(settings.HookName)
	hookNamespace := hooks.NamespaceReplacedHook

	// Old hook can only be ignored by user ignores...
	isIgnored := func(namespacePath string) bool {
		ignored, byUser := ingores.IsIgnored(namespacePath)

		return ignored && byUser
	}

	isTrusted := func(hookPath string) (bool, string) {
		if settings.IsRepoTrusted {
			return true, ""
		}

		trusted, sha, e := checksums.IsTrusted(hookPath)
		log.AssertNoErrorPanicF(e, "Could not check trust status '%s'.", hookPath)

		return trusted, sha
	}

	hooks, err := hooks.GetAllHooksIn(settings.HookDir, hookName, hookNamespace, isIgnored, isTrusted, true)
	log.AssertNoErrorPanicF(err, "Errors while collecting hooks in '%s'.", settings.HookDir)

	if len(hooks) == 0 {
		log.DebugF("Old hook '%s' does not exist. -> Skip!", hookName)

		return
	}

	hook := hooks[0]
	if hook.Active && !hook.Trusted {
		// Active hook, but not trusted:
		// Show trust prompt to let user trust it or disable.
		showTrustPrompt(uiSettings, checksums, &hook)
	}

	if !hook.Active || !hook.Trusted {
		log.DebugF("Hook '%s' is skipped [active: '%v', trusted: '%v']",
			hook.Path, hook.Active, hook.Trusted)

		return
	}

	log.DebugF("Executing hook: '%s'.", hook.Path)
	err = cm.RunExecutable(&settings.ExecX, &hook, cm.UseStdStreams(true, true, true))

	log.AssertNoErrorPanicF(err, "Hook launch failed: '%q'.", hook)
}

func collectHooks(
	settings *HookSettings,
	uiSettings *UISettings,
	ignores *hooks.RepoIgnorePatterns,
	checksums *hooks.ChecksumStore) (h hooks.Hooks) {

	// Local hooks in repository
	h.LocalHooks = getHooksIn(
		settings, uiSettings, settings.RepositoryHooksDir,
		true, hooks.NamespaceRepositoryHook, ignores, checksums)

	// All shared hooks
	var allAddedShared = make([]string, 0)
	h.RepoSharedHooks = getRepoSharedHooks(settings, uiSettings, ignores, checksums, &allAddedShared)

	h.LocalSharedHooks = getConfigSharedHooks(
		settings,
		uiSettings,
		ignores,
		checksums,
		&allAddedShared,
		hooks.SharedHookTypeV.Local)

	h.GlobalSharedHooks = getConfigSharedHooks(
		settings,
		uiSettings,
		ignores,
		checksums,
		&allAddedShared,
		hooks.SharedHookTypeV.Global)

	return
}

func updateSharedHooks(settings *HookSettings, sharedHooks []hooks.SharedRepo, sharedType hooks.SharedHookType) {

	if settings.HookName != "post-merge" &&
		!(settings.HookName == "post-checkout" &&
			settings.Args[0] == git.NullRef) &&
		!strs.Includes(settings.GitX.GetConfigAll(hooks.GitCK_SharedUpdateTriggers, git.Traverse),
			settings.HookName) {

		log.Debug("Shared hooks not updated.")

		return
	}

	log.Debug("Updating all shared hooks.")
	_, err := hooks.UpdateSharedHooks(log, sharedHooks, sharedType)
	log.AssertNoError(err, "Errors while updating shared hooks repositories.")
}

func getRepoSharedHooks(
	settings *HookSettings,
	uiSettings *UISettings,
	ignores *hooks.RepoIgnorePatterns,
	checksums *hooks.ChecksumStore,
	allAddedHooks *[]string) (hs hooks.HookPrioList) {

	shared, err := hooks.LoadRepoSharedHooks(settings.InstallDir, settings.RepositoryDir)

	if err != nil {
		log.ErrorOrPanicF(settings.FailOnNonExistingSharedHooks, err,
			"Repository shared hooks are demanded but failed "+
				"to parse the file:\n'%s'",
			hooks.GetRepoSharedFile(settings.RepositoryDir))
	}

	updateSharedHooks(settings, shared, hooks.SharedHookTypeV.Repo)

	for i := range shared {
		shRepo := &shared[i]

		if checkSharedHook(settings, shRepo, allAddedHooks, hooks.SharedHookTypeV.Repo) {
			hs = getHooksInShared(settings, uiSettings, shRepo, ignores, checksums)
			*allAddedHooks = append(*allAddedHooks, shRepo.RepositoryDir)
		}
	}

	return
}

func getConfigSharedHooks(
	settings *HookSettings,
	uiSettings *UISettings,
	ignores *hooks.RepoIgnorePatterns,
	checksums *hooks.ChecksumStore,
	allAddedHooks *[]string,
	sharedType hooks.SharedHookType) (hs hooks.HookPrioList) {

	var shared []hooks.SharedRepo
	var err error

	switch sharedType {
	case hooks.SharedHookTypeV.Local:
		shared, err = hooks.LoadConfigSharedHooks(settings.InstallDir, settings.GitX, git.LocalScope)
	case hooks.SharedHookTypeV.Global:
		shared, err = hooks.LoadConfigSharedHooks(settings.InstallDir, settings.GitX, git.GlobalScope)
	default:
		cm.DebugAssertF(false, "Wrong shared type '%v'", sharedType)
	}

	if err != nil {
		log.ErrorOrPanicF(settings.FailOnNonExistingSharedHooks,
			err,
			"Shared hooks are demanded but failed "+
				"to parse the %s config:\n'%s'",
			hooks.GetSharedHookTypeString(sharedType),
			hooks.GitCK_Shared)
	}

	for i := range shared {
		shRepo := &shared[i]

		if checkSharedHook(settings, shRepo, allAddedHooks, sharedType) {
			hs = append(hs, getHooksInShared(settings, uiSettings, shRepo, ignores, checksums)...)
			*allAddedHooks = append(*allAddedHooks, shRepo.RepositoryDir)
		}
	}

	return
}

func checkSharedHook(
	settings *HookSettings,
	hook *hooks.SharedRepo,
	allAddedHooks *[]string,
	sharedType hooks.SharedHookType) bool {

	if strs.Includes(*allAddedHooks, hook.RepositoryDir) {
		log.WarnF(
			"Shared hooks entry:\n'%s'\n"+
				"is already listed and will be skipped.", hook.OriginalURL)

		return false
	}

	// Check that no local paths are in repository configured
	// shared hooks
	log.PanicIfF(!hooks.AllowLocalURLInRepoSharedHooks() &&
		sharedType == hooks.SharedHookTypeV.Repo && hook.IsLocal,
		"Shared hooks in '%[1]s' contain a local path\n"+
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
		hooks.GetRepoSharedFileRel(), hook.OriginalURL)

	// Check if existing otherwise skip or fail...
	exists, err := cm.IsPathExisting(hook.RepositoryDir)

	if !exists {

		mess := "Failed to execute shared hooks in:\n" +
			"'%s'\n"

		if hook.IsCloned {
			mess += "It is not available. To fix, run:\n" +
				"$ git hooks shared update"
		} else {
			mess += "It does not exist."
		}

		if !settings.FailOnNonExistingSharedHooks {
			mess += "\nContinuing..."
		}

		log.ErrorOrPanicF(settings.FailOnNonExistingSharedHooks, err, mess, hook.OriginalURL)

		return false
	}

	// If cloned check that the remote url
	// is the same as the specified
	// Note: GIT_DIR might be set (?bug?) (actually the case for post-checkout hook)
	if hook.IsCloned {
		url := git.CtxCSanitized(hook.RepositoryDir).GetConfig(
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

			log.ErrorOrPanicF(settings.FailOnNonExistingSharedHooks,
				nil, mess, hook.OriginalURL, url)

			return false
		}
	}

	return true
}

func getHooksIn(
	settings *HookSettings,
	uiSettings *UISettings,
	hooksDir string,
	addInternalIgnores bool,
	hookNamespace string,
	ignores *hooks.RepoIgnorePatterns,
	checksums *hooks.ChecksumStore) (batches hooks.HookPrioList) {

	log.DebugF("Getting hooks in '%s'", hooksDir)

	isTrusted := func(hookPath string) (bool, string) {
		if settings.IsRepoTrusted {
			return true, ""
		}

		trusted, sha, e := checksums.IsTrusted(hookPath)
		log.AssertNoErrorPanicF(e, "Could not check trust status '%s'.", hookPath)

		return trusted, sha
	}

	var internalIgnores hooks.HookPatterns

	if addInternalIgnores {
		var e error
		internalIgnores, e = hooks.GetHookPatternsHooksDir(hooksDir, []string{settings.HookName})
		log.AssertNoErrorPanicF(e, "Could not get worktree ignores in '%s'.", hooksDir)
	}

	isIgnored := func(namespacePath string) bool {
		ignored, _ := ignores.IsIgnored(namespacePath)

		return ignored || internalIgnores.Matches(namespacePath)
	}

	// Determine namespace
	ns, err := hooks.GetHooksNamespace(hooksDir)
	log.AssertNoErrorPanicF(err, "Could not get hook namespace in '%s'", hooksDir)
	if strs.IsNotEmpty(ns) {
		hookNamespace = ns
	}

	allHooks, err := hooks.GetAllHooksIn(
		hooksDir,
		settings.HookName,
		hookNamespace,
		isIgnored,
		isTrusted,
		true)

	log.AssertNoErrorPanicF(err, "Errors while collecting hooks in '%s'.", hooksDir)

	// @todo Make a priority list for executing all batches in parallel
	// First good solution: all sequential
	batches = make(hooks.HookPrioList, 0, len(allHooks))
	for i := range allHooks {

		hook := &allHooks[i]

		if hook.Active && !hook.Trusted {
			// Active hook, but not trusted:
			// Show trust prompt to let user trust it or disable.
			showTrustPrompt(uiSettings, checksums, hook)
		}

		if !hook.Active || !hook.Trusted {
			log.DebugF("Hook '%s' is skipped [active: '%v', trusted: '%v']",
				hook.Path, hook.Active, hook.Trusted)

			continue
		}

		batch := []hooks.Hook{*hook}
		batches = append(batches, batch)
	}

	return
}

func getHooksInShared(settings *HookSettings,
	uiSettings *UISettings,
	shRepo *hooks.SharedRepo,
	ignores *hooks.RepoIgnorePatterns,
	checksums *hooks.ChecksumStore) hooks.HookPrioList {

	hookNamespace := hooks.GetDefaultHooksNamespaceShared(shRepo)

	// 1. priority has non-dot folder 'githooks'
	dir := hooks.GetSharedGithooksDir(shRepo.RepositoryDir)
	if cm.IsDirectory(dir) {
		return getHooksIn(settings, uiSettings, dir, true, hookNamespace, ignores, checksums)
	}

	// 2. priority is the normal '.githooks' folder.
	// This is second, to allow internal development Githooks inside shared repos.
	dir = hooks.GetGithooksDir(shRepo.RepositoryDir)
	if cm.IsDirectory(dir) {
		return getHooksIn(settings, uiSettings, dir, true, hookNamespace, ignores, checksums)
	}

	// 3. Fallback to the whole repository.
	return getHooksIn(settings, uiSettings, shRepo.RepositoryDir, true, hookNamespace, ignores, checksums)
}

func logBatches(title string, hooks hooks.HookPrioList) {
	var l string

	if hooks == nil {
		log.DebugF("%s: none", title)
	} else {
		for bIdx, batch := range hooks {
			l += strs.Fmt(" Batch: %v\n", bIdx)
			for i := range batch {
				l += strs.Fmt("  - '%s' [runner: '%q']\n", batch[i].Path, batch[i].RunCmd)
			}
		}
		log.DebugF("%s :\n%s", title, l)
	}
}

func showTrustPrompt(
	uiSettings *UISettings,
	checksums *hooks.ChecksumStore,
	hook *hooks.Hook) {

	if hook.Trusted {
		return
	} else {
		mess := strs.Fmt("New or changed hook found:\n'%s'", hook.Path)

		acceptHook := uiSettings.AcceptAllChanges
		disableHook := false

		if !acceptHook {

			question := mess + "\nDo you accept the changes?"

			answer, err := uiSettings.PromptCtx.ShowPromptOptions(question,
				"(Yes, all, no, disable)",
				"Y/a/n/d",
				"Yes", "All", "No", "Disable")
			log.AssertNoError(err, "Could not show prompt.")

			switch answer {
			case "a":
				uiSettings.AcceptAllChanges = true
				fallthrough // nolint:nlreturn
			case "y":
				acceptHook = true
			case "d":
				disableHook = true
			default:
				// Don't run hook ...
			}
		} else {
			log.Info("-> Already accepted.")
		}

		if acceptHook || disableHook {
			err := hook.AssertSHA1()
			log.AssertNoError(err, "Could not compute SHA1 hash of '%s'.", hook.Path)
		}

		if acceptHook {
			hook.Trusted = true

			uiSettings.AppendTrustedHook(
				hooks.ChecksumResult{
					SHA1:          hook.SHA1,
					Path:          hook.Path,
					NamespacePath: hook.NamespacePath})

			checksums.AddChecksum(hook.SHA1, hook.Path)

		} else if disableHook {
			log.InfoF("-> Adding hook\n'%s'\nto disabled list.", hook.Path)

			hook.Active = false

			uiSettings.AppendDisabledHook(
				hooks.ChecksumResult{
					SHA1:          hook.SHA1,
					Path:          hook.Path,
					NamespacePath: hook.NamespacePath})
		}
	}
}

func executeHooks(settings *HookSettings, hs *hooks.Hooks) {

	var nThreads = runtime.NumCPU()
	nThSetting := settings.GitX.GetConfig(hooks.GitCK_NumThreads, git.Traverse)
	if n, err := strconv.Atoi(nThSetting); err == nil {
		nThreads = n
	}

	var pool *threadpool.ThreadPool
	if hooks.UseThreadPool && hs.GetHooksCount() >= 2 {
		log.Debug("Create thread pool")
		p := threadpool.New(nThreads, 15)
		pool = &p
	}

	var results []hooks.HookResult
	var err error

	log.DebugIf(len(hs.LocalHooks) != 0, "Launching local hooks ...")
	results, err = hooks.ExecuteHooksParallel(pool, &settings.ExecX, &hs.LocalHooks, results, settings.Args...)
	log.AssertNoErrorPanic(err, "Local hook execution failed.")
	logHookResults(results)

	log.DebugIf(len(hs.RepoSharedHooks) != 0, "Launching repository shared hooks ...")
	results, err = hooks.ExecuteHooksParallel(pool, &settings.ExecX, &hs.RepoSharedHooks, results, settings.Args...)
	log.AssertNoErrorPanic(err, "Local hook execution failed.")
	logHookResults(results)

	log.DebugIf(len(hs.LocalSharedHooks) != 0, "Launching local shared hooks ...")
	results, err = hooks.ExecuteHooksParallel(pool, &settings.ExecX, &hs.LocalSharedHooks, results, settings.Args...)
	log.AssertNoErrorPanic(err, "Local hook execution failed.")
	logHookResults(results)

	log.DebugIf(len(hs.GlobalSharedHooks) != 0, "Launching global shared hooks ...")
	results, err = hooks.ExecuteHooksParallel(pool, &settings.ExecX, &hs.GlobalSharedHooks, results, settings.Args...)
	log.AssertNoErrorPanic(err, "Local hook execution failed.")
	logHookResults(results)
}

func logHookResults(res []hooks.HookResult) {
	for _, r := range res {
		if r.Error == nil {
			if len(r.Output) != 0 {
				_, _ = log.GetInfoWriter().Write(r.Output)
			}
		} else {
			if len(r.Output) != 0 {
				_, _ = log.GetErrorWriter().Write(r.Output)
			}
			log.AssertNoErrorPanicF(r.Error, "Hook '%s %q' failed!",
				r.Hook.GetCommand(), r.Hook.GetArgs())
		}
	}
}

func storePendingData(
	settings *HookSettings,
	uiSettings *UISettings,
	ignores *hooks.RepoIgnorePatterns,
	checksums *hooks.ChecksumStore) {

	// Store all ignore user patterns if there are new ones.
	if len(uiSettings.DisabledHooks) != 0 {

		// Add all back to the list ...
		for i := range uiSettings.DisabledHooks {
			ignores.User.AddNamespacePaths(uiSettings.DisabledHooks[i].NamespacePath)
		}

		// ... and store them
		err := hooks.StoreHookPatternsGitDir(ignores.User, settings.GitDirWorktree)
		log.AssertNoErrorF(err, "Could not store disabled hooks.")
	}

	// Store all checksums if there are any new ones.
	if len(uiSettings.TrustedHooks) != 0 {
		err := checksums.SyncChecksumAdd(uiSettings.TrustedHooks...)
		log.AssertNoErrorF(err, "Could not store checksum for hook")
	}
}
