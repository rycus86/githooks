package main

import (
	"os"
	path "path/filepath"
	cm "rycus86/githooks/common"

	"github.com/go-git/go-git/v5"
)

type hookSettings struct {
	hookPath   string
	hookName   string
	hookFolder string

	repository *git.Repository
	installDir string
}

func setMainVariables() hookSettings {

	cm.AssertFatal(
		len(os.Args) <= 1,
		"Hook name not specified as first argument -> Abort")

	installDir := getInstallDir()

	cwd, err := os.Getwd()
	cm.AssertNoErrorF(err, "Could not get current working dir")

	repository, err := git.PlainOpenWithOptions(
		cwd,
		&git.PlainOpenOptions{DetectDotGit: true})

	cm.AssertNoErrorF(err,
		cm.Fmt("Could not open current working dir Git repository '%s'", cwd))

	return hookSettings{
		hookPath:   os.Args[1],
		hookName:   path.Base(os.Args[1]),
		hookFolder: path.Dir(os.Args[1]),
		repository: repository,
		installDir: installDir}

}

func getInstallDir() string {
	return ""
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
