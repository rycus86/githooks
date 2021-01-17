// +build mock debug

package hooks

import (
	"os"
	"rycus86/githooks/git"
)

const (
	UseThreadPool = true
)

func AllowLocalURLInRepoSharedHooks() bool {
	return git.Ctx().GetConfig("githooks.testingTreatFileProtocolAsRemote", git.Traverse) == "true"
}

// GetDefaultCloneURL returns the default clone url.
func GetDefaultCloneURL() string {
	return os.Getenv("GH_TEST_REPO")
}

// GetDefaultCloneBranch returns the default clone branch name.
func GetDefaultCloneBranch() string {
	return "master"
}
