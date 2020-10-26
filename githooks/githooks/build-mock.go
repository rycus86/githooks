// +build mock debug

package hooks

import (
	"rycus86/githooks/git"
)

const (
	UseThreadPool = true
)

func AllowLocalURLInRepoSharedHooks() bool {
	return git.Ctx().GetConfig("githooks.testingTreatFileProtocolAsRemote", git.Traverse) == "true"
}
