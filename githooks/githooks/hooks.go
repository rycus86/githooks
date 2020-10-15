package hooks

import cm "rycus86/githooks/common"

// Hook contains the data to a executbale hook
type Hook = cm.Executable

// HookPrioList is a list of lists of executable hooks.
// Each list contains a set of hooks which can potentially
// be executed in parallel.
type HookPrioList [][]Hook

type sharedHookEnum struct {
	Repo   int
	Local  int
	Global int
}

// SharedHookEnum enumerates all types of shared hooks.
var SharedHookEnum = &sharedHookEnum{Repo: 0, Local: 1, Global: 2}

// GetSharedHookTypeString translates the shared type enum to a string
func GetSharedHookTypeString(sharedType int) string {
	switch sharedType {
	case SharedHookEnum.Repo:
		return "repo"
	case SharedHookEnum.Local:
		return "local"
	case SharedHookEnum.Global:
		return "global"
	default:
		cm.DebugAssert(false)
		return "wrong-value"
	}
}

// Hooks is a collection of all executable hooks.
type Hooks struct {
	LocalHooks        HookPrioList
	RepoSharedHooks   HookPrioList
	LocalSharedHooks  HookPrioList
	GlobalSharedHooks HookPrioList
}
