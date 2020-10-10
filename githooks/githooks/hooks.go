package hooks

// Hook contains the data to a executbale hook
type Hook struct {
	// The absolute path of the hook.
	Path string
	// The run command for the hook.
	RunCmd []string
}

// HookPrioList is a list of lists of executable hooks.
// Each list contains a set of hooks which can potentially
// be executed in parallel.
type HookPrioList [][]Hook

// Hooks is a collection of all executable hooks.
type Hooks struct {
	LocalOldHook      Hook
	GlobalSharedHooks HookPrioList
	LocalSharedHooks  HookPrioList
	LocalHooks        HookPrioList
}
