package hooks

import cm "rycus86/githooks/common"

// Hook contains the data to a executbale hook
type Hook = cm.Executable

// HookPrioList is a list of lists of executable hooks.
// Each list contains a set of hooks which can potentially
// be executed in parallel.
type HookPrioList [][]Hook

// Hooks is a collection of all executable hooks.
type Hooks struct {
	GlobalSharedHooks HookPrioList
	LocalSharedHooks  HookPrioList
	LocalHooks        HookPrioList
}
