package main

import (
	"os"
	path "path/filepath"
	cm "rycus86/githooks/common"

	"github.com/mitchellh/go-homedir"
)

type hookSettings struct {
	repositoryPath string
	installDir     string

	hookPath   string
	hookName   string
	hookFolder string
}

func setMainVariables() hookSettings {

	cm.AssertFatal(
		len(os.Args) <= 1,
		"Hook name not specified as first argument -> Abort")

	installDir := getInstallDir()

	cwd, err := os.Getwd()
	cm.AssertNoErrorF(err, "Could not get current working dir")

	return hookSettings{
		repositoryPath: cwd,
		installDir:     installDir,
		hookPath:       os.Args[1],
		hookName:       path.Base(os.Args[1]),
		hookFolder:     path.Dir(os.Args[1])}
}

func getInstallDir() string {
	installDir := cm.GitConfigGet("githooks.installDir", cm.GlobalScope)

	setDefault := func() {
		usr, err := homedir.Dir()
		cm.AssertNoErrorF(err, "Could not get home directory")
		installDir = path.Join(usr, ".githooks")
	}

	if installDir == "" {
		setDefault()
	} else if !cm.PathExists(installDir) {
		cm.LogWarn(
			"Githooks installation is corrupt! ",
			cm.Fmt("Install directory at '%s' is missing.", installDir))

		setDefault()

		cm.LogWarn(
			cm.Fmt("Falling back to default directory at '%s'", installDir),
			"Please run the Githooks install script again to fix it.")
	}

	cm.LogDebug(cm.Fmt("Install dir set to: '%s'", installDir))
	return installDir
}

func main() {

	// Handle all panics and report the error
	defer func() {
		if r := recover(); r != nil {
			err := r.(error)
			cm.LogError(err)
		}
	}()

	settings := setMainVariables()

	cm.LogDebug(cm.Fmt(
		"Running hook: '%s'", settings.hookPath),
		"We now going to rip apart your whole repo",
		"you dont think so ?")
}
