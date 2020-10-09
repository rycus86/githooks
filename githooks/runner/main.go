// Base Git hook template from https://github.com/rycus86/githooks
//
// It allows you to have a .githooks folder per-project that contains
// its hooks to execute on various Git triggers.
//
// Legacy version number. Not used anymore, but old installs read it.
// Version: 9912.310000-000000

package main

import (
	"os"
	"path/filepath"
	path "path/filepath"
	cm "rycus86/githooks/common"
	hooks "rycus86/githooks/githooks"
	strs "rycus86/githooks/strings"
	"strings"

	"github.com/mitchellh/go-homedir"
)

var log = cm.GetLogContext()

type hookSettings struct {
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

func (s *hookSettings) ToString() string {
	return strs.Fmt("\n- Args: '%s'\n"+
		"- Repo Path: '%s'\n"+
		"- Git Dir: '%s'\n"+
		"- Install Dir: '%s'\n"+
		"- Hook Path: '%s'\n"+
		"- Trusted: '%v'",
		s.args, s.repositoryPath, s.gitDir, s.installDir, s.hookPath, s.isTrusted)
}

func setMainVariables(repoPath string) hookSettings {

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

	installDir := getInstallDir(git)

	isTrusted, err := hooks.IsRepoTrusted(git,
		installDir, repoPath, true)
	log.AssertNoErrorWarn(err, "Could not get trust settings.")

	s := hookSettings{
		args:           os.Args[2:],
		git:            git,
		repositoryPath: repoPath,
		gitDir:         gitDir,
		installDir:     installDir,
		hookPath:       hookPath,
		hookName:       path.Base(hookPath),
		hookDir:        path.Dir(hookPath),
		isTrusted:      isTrusted}

	log.LogDebugF(s.ToString())

	return s
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
	} else if !cm.PathExists(installDir) {

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

func executeLFSHooksIfAppropriate(settings hookSettings) {

	if !strs.Includes(hooks.LFSHookNames[:], settings.hookName) {
		return
	}

	lfsIsAvailable := hooks.IsLFSAvailable()
	lfsIsRequired := cm.PathExists(filepath.Join(
		settings.repositoryPath, ".githooks", ".lfs-required"))

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

func executeHook(settings hookSettings, hook hooks.Hook) {
	log.LogDebugF("Executing hook: '%s'", hook.Path)
}

func executeOldHooksIfAvailable(settings hookSettings,
	ignorePatterns hooks.HookIgnorePatterns,
	checksums hooks.ChecksumStore) {

	hookName := settings.hookName + ".replaced.githook"

	// Make it relative to git directory
	// e.g. 'hooks/pre-commit.replaced.githooks'
	hook := filepath.Join(settings.hookPath, hookName)

	ignored := ignorePatterns.Matches(hookName)

	if ignored {
		log.LogDebugF("Old local hook '%s' is ignored -> Skip.", hook)
		return
	}

	if !settings.isTrusted {
		// @todo Check if it is trusted or not ...
	}

	runCmd, err := hooks.GetHookRunCmd(hook)
	if err != nil {
		log.AssertNoErrorWarnF(err, "Could not detect runner for hook\n'%s'\n-> Skip it!", hook)
		return
	}

	executeHook(settings,
		hooks.Hook{Path: hook, RunCmd: runCmd})
}

func exportStagedFiles(settings hookSettings) {
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

func getIgnorePatterns(settings hookSettings) hooks.HookIgnorePatterns {
	ignorePatterns, err := hooks.GetHookIgnorePatterns(
		settings.repositoryPath,
		settings.gitDir,
		settings.hookName)
	log.AssertNoErrorWarn(err, "Could not get hook ignore patterns.")
	log.LogDebugF("Ignore patterns: '%v'", ignorePatterns.Patterns)
	return ignorePatterns
}

func getLocalChecksumStore(settings hookSettings) hooks.ChecksumStore {
	localChecksums := filepath.Join(settings.gitDir, ".githooks.checksum")
	store, err := hooks.NewChecksumStore(localChecksums, false)
	log.AssertNoErrorWarnF(err, "Could not init checksum store in '%s'", localChecksums)
	log.LogDebug(store.Summary())

	return store
}

func main() {

	startTime := cm.GetStartTime()
	exitCode := 0

	defer func() { os.Exit(exitCode) }()
	defer func() {
		log.LogDebugF("Runner execution time: '%v'",
			cm.GetDuration(startTime))
	}()

	cwd, err := os.Getwd()

	// Handle all panics and report the error
	defer func() {
		r := recover()
		if r == nil {
			return
		}
		switch v := r.(type) {
		case cm.GithooksFailure:
			log.LogError("Fatal error -> Abort.")
		case error:
			log.LogErrorWithStacktrace(
				v.Error(),
				hooks.GetBugReportingInfo(cwd))
		default:
			log.LogErrorWithStacktrace(
				"Panic 💩: Unknown error",
				hooks.GetBugReportingInfo(cwd))
		}
		exitCode = 1
	}()

	cm.AssertNoErrorPanic(err, "Could not get current working dir.")

	settings := setMainVariables(cwd)

	assertRegistered(settings.git, settings.installDir, settings.gitDir)

	checksums := getLocalChecksumStore(settings)
	ignores := getIgnorePatterns(settings)

	if hooks.IsGithooksDisabled(settings.git) {
		executeLFSHooksIfAppropriate(settings)
		executeOldHooksIfAvailable(settings, ignores, checksums)
		return
	}

	exportStagedFiles(settings)
	executeLFSHooksIfAppropriate(settings)
	executeOldHooksIfAvailable(settings, ignores, checksums)

	//executeHooks(settings, ignores)
}
