//go:generate go run -mod=vendor ../../tools/generate-version.go
package main

import (
	"fmt"
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
	assertRegistered(settings.GitX, settings.InstallDir, settings.GitDir)

	checksums, err := hooks.GetChecksumStorage(settings.GitX, settings.GitDir)
	log.AssertNoErrorF(err, "Errors while loading checksum store.")
	log.DebugF("%s", checksums.Summary())

	ignores, err := hooks.GetIgnorePatterns(settings.RepositoryHooksDir, settings.GitDir, []string{settings.HookName})
	log.AssertNoErrorF(err, "Errors while loading ignore patterns.")
	log.DebugF("Worktree ignore patterns: '%q'.", ignores.Worktree)
	log.DebugF("User ignore patterns: '%q'.", ignores.User)

	defer storePendingData(&settings, &uiSettings, &ignores, &checksums)

	if hooks.IsGithooksDisabled(settings.GitX, true) {
		executeLFSHooks(&settings)
		executeOldHooks(&settings, &uiSettings, &ignores, &checksums)

		return
	}

	exportStagedFiles(&settings)
	updateGithooks(&settings, &uiSettings)
	executeLFSHooks(&settings)
	executeOldHooks(&settings, &uiSettings, &ignores, &checksums)

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

	gitDir, err := gitx.GetGitCommonDir()
	cm.AssertNoErrorPanic(err, "Could not get git directory.")

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

	isTrusted, err := hooks.IsRepoTrusted(gitx, promptCtx, repoPath, true)
	log.AssertNoError(err, "Could not get trust settings.")

	failOnNonExistingHooks := gitx.GetConfig(hooks.GitCK_FailOnNonExistingSharedHooks, git.Traverse) == "true"

	s := HookSettings{
		Args:               os.Args[2:],
		ExecX:              execx,
		GitX:               gitx,
		RepositoryDir:      repoPath,
		RepositoryHooksDir: path.Join(repoPath, hooks.HooksDirName),
		GitDir:             gitDir,
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

func assertRegistered(gitx *git.Context, installDir string, gitDir string) {

	if !gitx.IsConfigSet(hooks.GitCK_Registered, git.LocalScope) &&
		!gitx.IsConfigSet(git.GitCK_CoreHooksPath, git.Traverse) {

		log.DebugF("Register repo '%s'", gitDir)

		err := hooks.RegisterRepo(gitDir, installDir, true, false)
		log.AssertNoErrorF(err, "Could not register repo '%s'.", gitDir)

		err = hooks.MarkRepoRegistered(gitx)
		log.AssertNoErrorF(err, "Could not set register flag in repo '%s'.", gitDir)

	} else {
		log.Debug(
			"Repository already registered or using 'core.hooksPath'.")
	}
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

	log.Info("Record update check time ...")
	err := settings.GitX.SetConfig(hooks.GitCK_AutoUpdateLastRun,
		fmt.Sprintf("%v", time.Now().Unix()), git.GlobalScope)
	log.AssertNoError(err, "Could not record update time.")

	log.Info("Checking for updates ...")
	cloneDir := hooks.GetReleaseCloneDir(settings.InstallDir)
	status, err := updates.FetchUpdates(cloneDir, "", "", true, updates.ErrorOnWrongRemote)
	log.AssertNoError(err, "Could not fetch updates.")
	if err != nil {
		return
	}
	log.DebugF("Fetch status: '%v'", status)

	if shouldRunUpdate(uiSettings, status) {

		_, err = updates.MergeUpdates(cloneDir, true) // Dry run the merge...

		log.AssertNoErrorF(err,
			"Update cannot run:\n"+
				"Your release clone '%s' cannot be fast-forward merged.\n"+
				"Either fix this or delete the clone to retry.",
			cloneDir)

		if err != nil {
			return
		}

		runUpdate(settings, status)

	} else {
		log.Info(
			"If you would like to disable auto-updates, run:",
			"  $ git hooks update disable")
	}
}

func shouldRunUpdateCheck(settings *HookSettings) bool {
	if settings.HookName != "post-commit" {
		return false
	}

	enabled := settings.GitX.GetConfig(hooks.GitCK_AutoUpdateEnabled, git.Traverse)
	if enabled != "true" && enabled != "Y" {
		return false
	}

	timeLastUpdate := settings.GitX.GetConfig(hooks.GitCK_AutoUpdateLastRun, git.GlobalScope)
	if timeLastUpdate == "" {
		return true
	}
	t, err := strconv.ParseInt(timeLastUpdate, 10, 64)
	log.AssertNoErrorF(err, "Could not parse update time")

	return time.Since(time.Unix(t, 0)).Hours() > 24.0 //nolint: gomnd
}

func shouldRunUpdate(uiSettings *UISettings, status updates.ReleaseStatus) bool {
	if status.IsUpdateAvailable {

		question := "There is a new Githooks update available:\n" +
			strs.Fmt(" -> Forward-merge to version '%s'\n", status.UpdateVersion) +
			"Would you like to install it now?"

		answer, err := uiSettings.PromptCtx.ShowPromptOptions(question,
			"(Yes, no)",
			"Y/n",
			"Yes", "No")
		log.AssertNoErrorF(err, "Could not show prompt.")

		if answer == "y" {
			return true
		}

	} else {
		log.Info("Githooks is on the latest version")
	}

	return false
}

func runUpdate(settings *HookSettings, status updates.ReleaseStatus) {

	exec := hooks.GetInstaller(settings.InstallDir)

	execX := settings.ExecX
	env := os.Environ()
	env = append(env, "GITHOOKS_INTERNAL_AUTO_UPDATE=true")
	execX.Env = env

	if cm.IsFile(exec.Path) {

		output, err := cm.GetCombinedOutputFromExecutable(
			&execX,
			&exec,
			false,
			"--internal-auto-update")

		// @todo installer: remove "--internal-autoupdate"

		log.InfoF("Update:\n%s", output)
		log.AssertNoErrorF(err, "Updating failed")

	} else {
		log.WarnF(
			"Could not execute update, because the installer:\n"+
				"'%s'\n"+
				"is not existing.", exec.Path)
	}
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

func executeOldHooks(settings *HookSettings,
	uiSettings *UISettings,
	ingores *hooks.RepoIgnorePatterns,
	checksums *hooks.ChecksumStore) {

	// e.g. 'hooks/pre-commit.replaced.githook's
	hook := hooks.Hook{}
	hookName := hooks.GetHookReplacementFileName(settings.HookName)
	hook.Path = path.Join(settings.HookDir, hookName) // Make it relative to git directory

	exists, err := cm.IsPathExisting(hook.Path)
	log.AssertNoErrorF(err, "Could not check path '%s'", hook.Path)
	if !exists {
		log.DebugF("Old hook:\n'%s'\ndoes not exist. -> Skip!", hook.Path)

		return
	}

	hook.NamespacePath = path.Join("hooks", hookName)
	hook.RunCmd, err = hooks.GetHookRunCmd(hook.Path)
	log.AssertNoErrorPanicF(err, "Could not detect runner for hook\n'%s'", hook.Path)

	// @todo Introduce namespacing here!
	ignored, byUser := ingores.IsIgnored(hookName)
	if ignored && byUser {
		// Old hook can only be ignored by user patterns!
		log.DebugF("Old local hook '%s' is ignored by user -> Skip.", hook.Path)

		return
	}

	if !settings.IsRepoTrusted &&
		!executeSafetyChecks(uiSettings, checksums, hook.Path, hook.NamespacePath) {
		log.DebugF("Hook '%s' skipped", hook.Path)

		return
	}

	log.DebugF("Executing hook: '%s'.", hook.Path)
	err = cm.RunExecutable(&settings.ExecX, &hook, true)

	log.AssertNoErrorPanicF(err, "Hook launch failed: '%q'.", hook)
}

func collectHooks(
	settings *HookSettings,
	uiSettings *UISettings,
	ignores *hooks.RepoIgnorePatterns,
	checksums *hooks.ChecksumStore) (h hooks.Hooks) {

	// Local hooks in repository
	h.LocalHooks = getHooksIn(settings, uiSettings, settings.RepositoryHooksDir, true, ignores, checksums)

	// All shared hooks
	var allAddedShared = make([]string, 0)
	h.RepoSharedHooks = getRepoSharedHooks(settings, uiSettings, ignores, checksums, &allAddedShared)

	h.LocalSharedHooks = getConfigSharedHooks(
		settings,
		uiSettings,
		ignores,
		checksums,
		&allAddedShared,
		hooks.SharedHookEnumV.Local)

	h.GlobalSharedHooks = getConfigSharedHooks(
		settings,
		uiSettings,
		ignores,
		checksums,
		&allAddedShared,
		hooks.SharedHookEnumV.Global)

	return
}

func updateSharedHooks(settings *HookSettings, sharedHooks []hooks.SharedHook, sharedType hooks.SharedHookEnum) {

	if settings.HookName != "post-merge" &&
		!(settings.HookName == "post-checkout" &&
			settings.Args[0] == git.NullRef) &&
		!strs.Includes(settings.GitX.GetConfigAll(hooks.GitCK_SharedUpdateTriggers, git.Traverse),
			settings.HookName) {

		log.Debug("Shared hooks not updated.")

		return
	}

	log.Debug("Updating all shared hooks.")
	_ = hooks.UpdateSharedHooks(log, sharedHooks, sharedType)
}

func getRepoSharedHooks(
	settings *HookSettings,
	uiSettings *UISettings,
	ignores *hooks.RepoIgnorePatterns,
	checksums *hooks.ChecksumStore,
	allAddedHooks *[]string) (hs hooks.HookPrioList) {

	sharedHooks, err := hooks.LoadRepoSharedHooks(settings.InstallDir, settings.RepositoryDir)

	if err != nil {
		log.ErrorOrPanicF(settings.FailOnNonExistingSharedHooks, err,
			"Repository shared hooks are demanded but failed "+
				"to parse the file:\n'%s'",
			hooks.GetRepoSharedFile(settings.RepositoryDir))
	}

	updateSharedHooks(settings, sharedHooks, hooks.SharedHookEnumV.Repo)

	for _, sharedHook := range sharedHooks {
		if checkSharedHook(settings, sharedHook, allAddedHooks, hooks.SharedHookEnumV.Repo) {
			hs = getHooksInShared(settings, uiSettings, sharedHook, ignores, checksums)
			*allAddedHooks = append(*allAddedHooks, sharedHook.RepositoryDir)
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
	sharedType hooks.SharedHookEnum) (hs hooks.HookPrioList) {

	var sharedHooks []hooks.SharedHook
	var err error

	switch sharedType {
	case hooks.SharedHookEnumV.Local:
		sharedHooks, err = hooks.LoadConfigSharedHooks(settings.InstallDir, settings.GitX, git.LocalScope)
	case hooks.SharedHookEnumV.Global:
		sharedHooks, err = hooks.LoadConfigSharedHooks(settings.InstallDir, settings.GitX, git.GlobalScope)
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

	for _, sharedHook := range sharedHooks {
		if checkSharedHook(settings, sharedHook, allAddedHooks, sharedType) {
			hs = append(hs, getHooksInShared(settings, uiSettings, sharedHook, ignores, checksums)...)
			*allAddedHooks = append(*allAddedHooks, sharedHook.RepositoryDir)
		}
	}

	return
}

func checkSharedHook(
	settings *HookSettings,
	hook hooks.SharedHook,
	allAddedHooks *[]string,
	sharedType hooks.SharedHookEnum) bool {

	if strs.Includes(*allAddedHooks, hook.RepositoryDir) {
		log.WarnF(
			"Shared hooks entry:\n'%s'\n"+
				"is already listed and will be skipped.", hook.OriginalURL)

		return false
	}

	// Check that no local paths are in repository configured
	// shared hooks
	log.PanicIfF(!hooks.AllowLocalURLInRepoSharedHooks() &&
		sharedType == hooks.SharedHookEnumV.Repo && hook.IsLocal,
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

func createHook(uiSettings *UISettings,
	isRepoTrusted bool,
	hookPath string,
	hookNamespacePath string,
	checksums *hooks.ChecksumStore) (hooks.Hook, bool) {

	// Check if trusted
	if !isRepoTrusted &&
		!executeSafetyChecks(uiSettings, checksums, hookPath, hookNamespacePath) {
		log.DebugF("Hook '%s' skipped", hookPath)

		return hooks.Hook{}, false
	}

	runCmd, err := hooks.GetHookRunCmd(hookPath)
	log.AssertNoErrorPanicF(err, "Could not detect runner for hook\n'%s'", hookPath)

	return hooks.Hook{
		Executable: cm.Executable{
			Path:   hookPath,
			RunCmd: runCmd},
		NamespacePath: hookNamespacePath}, true
}

func getHooksIn(settings *HookSettings,
	uiSettings *UISettings,
	hooksDir string,
	parseIgnores bool,
	externalIgnores *hooks.RepoIgnorePatterns,
	checksums *hooks.ChecksumStore) (batches hooks.HookPrioList) {

	log.DebugF("Getting hooks in '%s'", hooksDir)

	var ignores hooks.HookIgnorePatterns

	if parseIgnores {
		var e error
		ignores, e = hooks.GetHookIgnorePatternsWorktree(hooksDir, []string{settings.HookName})
		log.AssertNoErrorF(e, "Could not get worktree ignores in '%s'", hooksDir)
	}

	hookNamespace, err := hooks.GetHooksNamespace(hooksDir)
	log.AssertNoErrorF(err, "Could not read namespace file in '%s'", hooksDir)

	dirOrFile := path.Join(hooksDir, settings.HookName)

	// Collect all hooks in e.g. `path/pre-commit/*`
	if cm.IsDirectory(dirOrFile) {

		var allHooks []strs.Pair // Path and Namespaced path of the hook

		// Get all files and skip ingored hooks.
		// Use a namespace to check ignores.
		err := cm.WalkFiles(dirOrFile,
			func(hookPath string, _ os.FileInfo) {
				// Ignore `.xxx` files
				if strings.HasPrefix(path.Base(hookPath), ".") {
					return
				}

				// Namespace the path to check ignores
				namespacedPath := path.Join(hookNamespace, settings.HookName, path.Base(hookPath))
				ignored, _ := externalIgnores.IsIgnored(namespacedPath)
				ignored = ignored || ignores.IsIgnored(namespacedPath)

				if ignored {
					log.DebugF("Hook '%s' is ignored. -> Skip.", namespacedPath)
					return // nolint:nlreturn
				}

				allHooks = append(allHooks,
					strs.Pair{
						First:  hookPath,
						Second: namespacedPath})

			})

		log.AssertNoErrorF(err, "Errors while walking '%s'", dirOrFile)

		// @todo make a priority list for executing all batches in parallel
		// First good solution: all sequential
		for _, h := range allHooks {

			hook, use := createHook(uiSettings, settings.IsRepoTrusted, h.First, h.Second, checksums)
			if !use {
				continue
			}

			batch := []hooks.Hook{hook}
			batches = append(batches, batch)
		}

	} else if cm.IsFile(dirOrFile) { // Check hook in `path/pre-commit`

		// Namespace the path to check ignores
		namespacedPath := path.Join(hookNamespace, path.Base(dirOrFile))
		ignored, _ := externalIgnores.IsIgnored(namespacedPath)
		ignored = ignored || ignores.IsIgnored(namespacedPath)

		if ignored {
			log.DebugF("Hook '%s' is ignored. -> Skip.", namespacedPath)
			return // nolint:nlreturn
		}

		hook, use := createHook(uiSettings, settings.IsRepoTrusted, dirOrFile, namespacedPath, checksums)
		if use {
			batch := []hooks.Hook{hook}
			batches = append(batches, batch)
		}
	}

	return
}

func getHooksInShared(settings *HookSettings,
	uiSettings *UISettings,
	hook hooks.SharedHook,
	ignores *hooks.RepoIgnorePatterns,
	checksums *hooks.ChecksumStore) hooks.HookPrioList {

	// Legacy
	// @todo Remove this, dont support /.githooks because it will enable
	// using hooks in hook repos!
	dir := hooks.GetGithooksDir(hook.RepositoryDir)
	if cm.IsDirectory(dir) {
		return getHooksIn(settings, uiSettings, dir, true, ignores, checksums)
	}

	return getHooksIn(settings, uiSettings, hook.RepositoryDir, true, ignores, checksums)

}

func logBatches(title string, hooks hooks.HookPrioList) {
	var l string

	if hooks == nil {
		log.DebugF("%s: none", title)
	} else {
		for bIdx, batch := range hooks {
			l += strs.Fmt(" Batch: %v\n", bIdx)
			for _, h := range batch {
				l += strs.Fmt("  - '%s' [runner: '%q']\n", h.Path, h.RunCmd)
			}
		}
		log.DebugF("%s :\n%s", title, l)
	}
}

func executeSafetyChecks(uiSettings *UISettings,
	checksums *hooks.ChecksumStore,
	hookPath string,
	hookNamespacePath string) (runHook bool) {

	trusted, sha1, err := checksums.IsTrusted(hookPath)
	if !log.AssertNoErrorF(err,
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
				runHook = true
			case "d":
				log.InfoF("-> Adding hook\n'%s'\nto disabled list.", hookPath)

				uiSettings.AppendDisabledHook(
					hooks.ChecksumResult{
						SHA1:          sha1,
						Path:          hookPath,
						NamespacePath: hookNamespacePath})
			default:
				// Don't run hook ...
			}
		} else {
			log.Info("-> Already accepted.")
			acceptHook = true
			runHook = true
		}

		if acceptHook {

			uiSettings.AppendTrustedHook(
				hooks.ChecksumResult{
					SHA1:          sha1,
					Path:          hookPath,
					NamespacePath: hookNamespacePath})

			checksums.AddChecksum(sha1, hookPath)
		}
	}

	return
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
		err := hooks.StoreHookIgnorePatternsGitDir(ignores.User, settings.GitDir)
		log.AssertNoErrorF(err, "Could not store disabled hooks.")
	}

	// Store all checksums if there are any new ones.
	if len(uiSettings.TrustedHooks) != 0 {
		for i := range uiSettings.TrustedHooks {

			err := checksums.SyncChecksum(uiSettings.TrustedHooks[i])

			log.AssertNoErrorF(err, "Could not store checksum for hook '%s'",
				uiSettings.TrustedHooks[i].Path)
		}
	}

	if hooks.ReadWriteLegacyTrustFile {
		// Legacy function write disabled and trusted hooks back to `.githooks.checksum`
		// @todo write them to the correct file!
		localChecksums := path.Join(settings.GitDir, ".githooks.checksum")
		f, err := os.OpenFile(localChecksums, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0664)
		log.AssertNoErrorPanicF(err, "Could not open file '%s'", localChecksums)
		defer f.Close()

		for _, d := range uiSettings.DisabledHooks {
			_, err := f.WriteString(fmt.Sprintf("disabled> %s\n", d.Path))
			cm.AssertNoErrorPanic(err)
		}

		for _, d := range uiSettings.TrustedHooks {
			_, err := f.WriteString(fmt.Sprintf("%s %s\n", d.SHA1, d.Path))
			cm.AssertNoErrorPanic(err)
		}
	}
}
