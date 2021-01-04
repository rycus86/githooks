package hooks

import (
	"os"
	"path"
	cm "rycus86/githooks/common"
	strs "rycus86/githooks/strings"
	"strings"

	thx "github.com/pbenner/threadpool"
)

// Hook contains the data to an executbale hook.
type Hook struct {
	cm.Executable // The executable of the hook.

	NamespacePath string // The namespaced path of the hook `<namespace>/<relPath>`.

	Active  bool // If the hook is not ignored by any ignore patterns. Has priority 1.
	Trusted bool // If the hook is trusted by means of the chechsum store. Has priority 2.

	SHA1 string // SHA1 hash of the hook. (if determined)
}

// HookPrioList is a list of lists of executable hooks.
// Each list contains a set of hooks which can potentially
// be executed in parallel.
type HookPrioList [][]Hook

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

type IngoreCallback = func(namespacePath string) (ignored bool)
type TrustCallback = func(hookPath string) (trusted bool, sha1 string)

func GetAllHooksIn(
	hooksDir string,
	hookName string,
	hookNamespace string,
	isIgnored IngoreCallback,
	isTrusted TrustCallback) (allHooks []Hook, err error) {

	appendHook := func(hookPath string, hookNamespace string) error {
		// Namespace the path to check ignores
		namespacedPath := path.Join(hookNamespace, path.Base(hookPath))
		ignored := isIgnored(namespacedPath)

		trusted := false
		sha := ""
		var runCmd []string

		if !ignored {
			trusted, sha = isTrusted(hookPath)

			if runCmd, err = GetHookRunCmd(hookPath); err != nil {
				return cm.CombineErrors(err,
					cm.ErrorF("Could not detect runner for hook\n'%s'", hookPath))
			}
		}

		allHooks = append(allHooks,
			Hook{
				Executable:    cm.Executable{Path: hookPath, RunCmd: runCmd},
				NamespacePath: namespacedPath,
				Active:        !ignored,
				Trusted:       trusted,
				SHA1:          sha})

		return nil
	}

	dirOrFile := path.Join(hooksDir, hookName)

	// Collect all hooks in e.g. `path/pre-commit/*`
	if cm.IsDirectory(dirOrFile) {

		err = cm.WalkFiles(dirOrFile,
			func(hookPath string, _ os.FileInfo) error {

				// Ignore `.dotfile` files
				if strings.HasPrefix(path.Base(hookPath), ".") {
					return nil
				}

				return appendHook(hookPath, path.Join(hookNamespace, hookName))
			})

		if err != nil {
			err = cm.CombineErrors(cm.ErrorF("Errors while walking '%s'", dirOrFile), err)

			return
		}

	} else if cm.IsFile(dirOrFile) { // Check hook in `path/pre-commit`
		err = appendHook(dirOrFile, hookNamespace)
	}

	return
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

// AssertSHA1 ensures that the hook has its SHA1 computed.
func (h *Hook) AssertSHA1() (err error) {
	if strs.IsEmpty(h.SHA1) {
		h.SHA1, err = cm.GetSHA1HashFile(h.Path)
	}

	return
}
