package main

import (
	"os"
	path "path/filepath"
	cm "rycus86/githooks/common"
	strs "rycus86/githooks/strings"

	"github.com/mitchellh/go-homedir"
)

var log = cm.GetLogContext()

type hookSettings struct {
	git            *cm.GitContext
	repositoryPath string
	gitDir         string
	installDir     string

	hookPath   string
	hookName   string
	hookFolder string
}

func setMainVariables() hookSettings {

	log.AssertFatal(
		len(os.Args) <= 1,
		"Hook name not specified as first argument -> Abort")

	cwd, err := os.Getwd()
	log.AssertNoErrorFatal(err, "Could not get current working dir.")

	git := cm.Git() // Current git context, in current working dir.

	gitDir, err := git.Get("rev-parse", "--git-common-dir")
	log.LogDebugF("Git dir: '%s'", gitDir)
	log.AssertNoErrorFatal(err, "Could not get git directory.")

	installDir := getInstallDir(git)

	return hookSettings{
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

func assertRegistered(settings hookSettings) {

	if !settings.git.IsConfigSet("githooks.registered", cm.LocalScope) &&
		!settings.git.IsConfigSet("core.hooksPath", cm.Traverse) {

		registerRepo(settings.gitDir, settings.installDir)

	} else {
		log.LogDebug("Repository already registered or using 'core.hooksPath'.")
	}
}

func registerRepo(gitDir string, installDir string) {

	var registerFile = path.Join(installDir, "registered.yml")
	log.LogDebugF("Registering repo in '%s'", registerFile)

	repos, err := cm.GetRegisteredRepos(registerFile)

	log.AssertWarn(err != nil,
		strs.Fmt("Could not load registered file '%s'.", registerFile))

	repos.Insert(gitDir)
	log.LogDebugF("%s", gitDir)
	err = cm.SetRegisteredRepos(repos, registerFile)

	log.AssertNoErrorWarn(err,
		strs.Fmt("Could not save registered file '%s'.", registerFile))
}

func main() {

	// Handle all panics and report the error
	defer func() {
		if r := recover(); r != nil {
			err := r.(error)
			log.LogError(strs.Fmt("Panic received -> Abort [error: '%s']", err))
		}
	}()

	settings := setMainVariables()

	assertRegistered(settings)

	log.LogDebug(strs.Fmt(
		"Running hook: '%s'", settings.hookPath),
		"We now going to rip apart your whole repo",
		"you dont think so ?")
}
