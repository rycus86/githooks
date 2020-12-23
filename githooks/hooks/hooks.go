package hooks

import (
	cm "rycus86/githooks/common"

	thx "github.com/pbenner/threadpool"
)

// Hook contains the data to an executbale hook.
type Hook struct {
	cm.Executable
	NamespacePath string // The namespaced path of the hook `<namespace>/<relPath>`.
}

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
var SharedHookEnum = &sharedHookEnum{Repo: 0, Local: 1, Global: 2} // nolint:gomnd

// GetSharedHookTypeString translates the shared type enum to a string.
func GetSharedHookTypeString(sharedType int) string {
	switch sharedType {
	case SharedHookEnum.Repo:
		return "repo"
	case SharedHookEnum.Local:
		return "local"
	case SharedHookEnum.Global:
		return "global"
	default:
		cm.DebugAssertF(false, "Wrong type '%s'", sharedType)
		return "wrong-value" // nolint:nlreturn
	}
}

// Hooks is a collection of all executable hooks.
type Hooks struct {
	LocalHooks        HookPrioList
	RepoSharedHooks   HookPrioList
	LocalSharedHooks  HookPrioList
	GlobalSharedHooks HookPrioList
}

// HookResult is the data assembly of the output of an executed hook.
type HookResult struct {
	Hook   *Hook
	Output []byte
	Error  error
}

// ExecuteHooksParallel executes hooks in parallel over a thread pool.
func ExecuteHooksParallel(
	pool *thx.ThreadPool,
	exec cm.IExecContext,
	hs *HookPrioList,
	res []HookResult,
	args ...string) ([]HookResult, error) {

	// Count number of results we need
	nResults := 0
	for _, hooksGroup := range *hs {
		nResults += len(hooksGroup)
	}

	// Assert results is the right size
	if nResults > len(res) {
		res = append(res, make([]HookResult, nResults-len(res))...)
	} else {
		res = res[:nResults]
	}

	currIdx := 0
	for _, hooksGroup := range *hs {
		nHooks := len(hooksGroup)

		if nHooks == 0 {
			continue
		}

		if pool == nil {
			for idx := range hooksGroup {
				var err error
				res[currIdx+idx].Output, err = cm.GetCombinedOutputFromExecutable(exec, &hooksGroup[idx], true, args...)
				res[currIdx+idx].Error = err
				res[currIdx+idx].Hook = &hooksGroup[idx]
			}
		} else {
			g := pool.NewJobGroup()

			err := pool.AddRangeJob(0, nHooks, g,
				func(idx int, pool thx.ThreadPool, erf func() error) error {
					hook := &hooksGroup[idx]
					var err error
					res[currIdx+idx].Output, err =
						cm.GetCombinedOutputFromExecutable(exec, hook, true, args...)

					res[currIdx+idx].Error = err
					res[currIdx+idx].Hook = hook

					return nil
				})

			if err != nil {
				return nil, err
			}

			if err = pool.Wait(g); err != nil {
				return nil, err
			}

		}

		currIdx += nHooks
	}

	return res, nil
}

// GetHooksCount gets the number of all hooks.
func (h *Hooks) GetHooksCount() int {
	return len(h.LocalHooks) + len(h.RepoSharedHooks) + len(h.LocalSharedHooks) + len(h.GlobalSharedHooks)
}

// AllHooksSuccessful returns `true`.
func AllHooksSuccessful(results []HookResult) bool {
	for _, h := range results {
		if h.Error != nil {
			return false
		}
	}

	return true
}
