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
	"runtime"
	cm "rycus86/githooks/common"
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

	log.AssertFatal(
		len(os.Args) >= 2,
		"Hook name not specified as first argument -> Abort")

	git := cm.Git() // Current git context, in current working dir.

	gitDir, err := git.Get("rev-parse", "--git-common-dir")
	log.LogDebugF("Git dir: '%s'", gitDir)
	log.AssertNoErrorFatal(err, "Could not get git directory.")

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
		log.AssertNoErrorFatal(err, "Could not get home directory.")
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

		err := cm.RegisterRepo(gitDir, installDir)

		log.AssertNoErrorWarn(err,
			strs.Fmt("Could not register repo '%s'.", gitDir))

	} else {
		log.LogDebug(
			"Repository already registered",
			"or using 'core.hooksPath'.")
	}
}

func executeLFSHooksIfAppropriate(settings hookSettings) {

	if !strs.Includes(cm.LFSHookNames[:], settings.hookName) {
		return
	}

	lfsIsAvailable := cm.IsLFSAvailable()
	lfsIsRequired := cm.PathExists(path.Join(
		settings.repositoryPath, ".githooks", ".lfs-required"))

	if lfsIsAvailable {

		err := settings.git.Check(
			append(
				[]string{"lfs", settings.hookName},
				settings.args...,
			)...)

		log.AssertNoErrorFatal(err, "Execution of LFS Hook failed.")

	} else {
		log.FatalIf(lfsIsRequired,
			"This repository requires Git LFS, but 'git-lfs' was",
			"not found on your PATH. If you no longer want to use",
			"Git LFS, remove the '.githooks/.lfs-required' file.",
		)
	}
}

func main() {

	cwd, err := os.Getwd()
	log.AssertNoErrorFatal(err, "Could not get current working dir.")

	// Handle all panics and report the error
	defer func() {
		if r := recover(); r != nil {
			switch v := r.(type) {
			case runtime.Error:
				log.LogErrorWithStacktrace(
					strs.Fmt("Panic: ['%s']", v.Error()),
					"",
					cm.GetBugReportingInfo(cwd))
			case error:
				log.LogDebug(strs.Fmt("Error received -> Abort"))
			}
		}
	}()

	err = nil
	s := err.Error()
	log.LogDebug(s)

	settings := setMainVariables(cwd)

	assertRegistered(settings.git, settings.installDir, settings.gitDir)

	if cm.IsGithooksDisabled(settings.git) {
		executeLFSHooksIfAppropriate(settings)
	}

	log.LogDebug(strs.Fmt(
		"Running hook: '%s'", settings.hookPath),
		"We now going to rip apart your whole repo",
		"you dont think so ?")
}
