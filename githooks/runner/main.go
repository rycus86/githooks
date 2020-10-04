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
	path "path/filepath"
	cm "rycus86/githooks/common"
	hooks "rycus86/githooks/githooks"
	strs "rycus86/githooks/strings"

	"github.com/mitchellh/go-homedir"
)

var log = cm.GetLogContext()

type hookSettings struct {
	args           []string       // Rest arguments.
	git            *cm.GitContext // Git context to execute commands (working dir is this repository)
	repositoryPath string         // Repository path.
	gitDir         string         // Git directory.
	installDir     string         // Install directory.

	hookPath   string // Path of the hook executing this runner.
	hookName   string // Name of the hook.
	hookFolder string // Directory of the hook.
}

func setMainVariables(cwd string) hookSettings {

	cm.PanicIf(
		len(os.Args) <= 1,
		"No arguments given! -> Abort")

	git := cm.Git() // Current git context, in current working dir.
	gitDir, err := git.Get("rev-parse", "--git-common-dir")
	cm.AssertNoErrorPanic(err, "Could not get git directory.")
	gitDir, err = path.Abs(gitDir)
	cm.AssertNoErrorPanic(err, "Could not get git directory.")

	log.LogDebugF("Git dir: '%s'", gitDir)
	log.LogDebugF("Args: '%s'", os.Args[2:])

	installDir := getInstallDir(git)

	return hookSettings{
		args:           os.Args[2:],
		git:            git,
		repositoryPath: cwd,
		gitDir:         gitDir,
		installDir:     installDir,
		hookPath:       os.Args[1],
		hookName:       path.Base(os.Args[1]),
		hookFolder:     path.Dir(os.Args[1])}
}

func getInstallDir(git *cm.GitContext) string {
	installDir := git.GetConfig("githooks.installDir", cm.GlobalScope)

	setDefault := func() {
		usr, err := homedir.Dir()
		cm.AssertNoErrorPanic(err, "Could not get home directory.")
		installDir = path.Join(usr, ".githooks")
	}

	if installDir == "" {
		setDefault()
	} else if !cm.PathExists(installDir) {

		log.LogWarn(
			"Githooks installation is corrupt!",
			strs.Fmt("Install directory at '%s' is missing.", installDir))

		setDefault()

		log.LogWarn(
			strs.Fmt("Falling back to default directory at '%s'.", installDir),
			"Please run the Githooks install script again to fix it.")
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
	lfsIsRequired := cm.PathExists(path.Join(
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

func executeHook(hook string, settings hookSettings) {
	log.LogDebugF("Executing hook: '%s'", hook)
}

func executeOldHooksIfAvailable(settings hookSettings) {
	f := settings.hookPath + ".replaced.githook"
	hook, err := path.Abs(f)
	cm.AssertNoErrorPanic(err, "Could not get abs. path of '%s'", f)

	executeHook(hook, settings)
}

func main() {

	cwd, err := os.Getwd()

	// Handle all panics and report the error
	defer func() {
		r := recover()
		switch v := r.(type) {
		case cm.GithooksFailure:
			log.LogError("Fatal error -> Abort.")
		case error:
			log.LogErrorWithStacktrace(
				v.Error(),
				hooks.GetBugReportingInfo(cwd))
		default:
			log.LogErrorWithStacktrace(
				"Panic: Unknown error",
				hooks.GetBugReportingInfo(cwd))
		}
		os.Exit(1)
	}()

	cm.AssertNoErrorPanic(err, "Could not get current working dir.")

	settings := setMainVariables(cwd)

	log.LogDebugF("Running hook: '%s'", settings.hookPath)

	assertRegistered(settings.git, settings.installDir, settings.gitDir)

	if hooks.IsGithooksDisabled(settings.git) {
		executeLFSHooksIfAppropriate(settings)
		executeOldHooksIfAvailable(settings)
	}

	executeLFSHooksIfAppropriate(settings)

	os.Exit(0)
}
