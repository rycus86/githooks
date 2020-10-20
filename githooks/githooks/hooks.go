package hooks

import (
	cm "rycus86/githooks/common"

	thx "github.com/pbenner/threadpool"
)

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

// HookResult is the data assembly of the output of an executed hook.
type HookResult struct {
	Hook   *Hook
	Output []byte
	Error  error
}

// ExecuteHooksParallel executes hooks in paralell over a thread pool.
func ExecuteHooksParallel(
	pool *thx.ThreadPool,
	exec cm.IExecContext,
	hs *HookPrioList,
	res []HookResult,
	args ...string) []HookResult {

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
			for idx, hook := range hooksGroup {
				var err error
				res[currIdx+idx].Output, err = cm.GetCombinedOutputFromExecutable(exec, &hook, true, args...)
				res[currIdx+idx].Error = err
				res[currIdx+idx].Hook = &hook
			}
		} else {
			g := pool.NewJobGroup()

			pool.AddRangeJob(0, nHooks, g,
				func(idx int, pool thx.ThreadPool, erf func() error) error {
					hook := &hooksGroup[idx]
					var err error
					res[currIdx+idx].Output, err =
						cm.GetCombinedOutputFromExecutable(exec, hook, true, args...)

					res[currIdx+idx].Error = err
					res[currIdx+idx].Hook = hook

					return nil
				})

			pool.Wait(g)
		}

		currIdx += nHooks
	}

	return res
}

// AllHooksSuccessful returns `true`
func AllHooksSuccessful(results []HookResult) bool {
	for _, h := range results {
		if h.Error != nil {
			return false
		}
	}
	return true
}
