package hooks

import (
	"os"
	"path"
	cm "rycus86/githooks/common"
	strs "rycus86/githooks/strings"
	"strings"

	thx "github.com/pbenner/threadpool"
)

// Hook contains the data to an executable hook.
type Hook struct {
	// The executable of the hook.
	cm.Executable

	// The namespaced path of the hook `<namespace>/<relPath>`.
	NamespacePath string

	// If the hook is not ignored by any ignore patterns.
	// Has priority 1 for execution determination.
	Active bool
	// If the hook is trusted by means of the chechsum store.
	// Has priority 2 for execution determination.
	Trusted bool

	// SHA1 hash of the hook. (if determined)
	SHA1 string
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

type TaggedHooksIndex int
type taggedHooksIndex struct {
	Replaced     TaggedHooksIndex
	Repo         TaggedHooksIndex
	SharedRepo   TaggedHooksIndex
	SharedLocal  TaggedHooksIndex
	SharedGlobal TaggedHooksIndex
	count        int
}

//nolint: gomnd
var TaggedHookIndices = taggedHooksIndex{
	Replaced:     0,
	Repo:         1,
	SharedRepo:   2,
	SharedLocal:  3,
	SharedGlobal: 4,
	count:        5}

// HookMap represents a map for all hooks sorted by tags.
// A list of hooks for each index `TaggedHookIndices`.
type TaggedHooks [][]Hook

// NewTaggedHooks returns a slice of hooks for each index `TaggedHookIndices`.
func NewTaggedHooks(capacity int) (res TaggedHooks) {
	res = make(TaggedHooks, TaggedHookIndices.count)
	for idx := range res {
		res[idx] = make([]Hook, 0, capacity)
	}

	return res
}

const (
	TagNameReplaced     = "replaced"      // Hook tag for replaced hooks.
	TagNameRepository   = "repo"          // Hook tag for repository hooks.
	TagNameSharedRepo   = "shared:repo"   // Hook tag for shared hooks inside the repository.
	TagNameSharedLocal  = "shared:local"  // Hook tag for shared hooks in the local Git config.
	TagNameSharedGLobal = "shared:global" // Hook tag for shared hooks in the global Git config.
)

// GetHookTagNameMappings gets the mapping of a hook tag to a name.
// Indexable by `HookTagV`.
func GetHookTagNameMappings() []string {
	return []string{
		TagNameReplaced,
		TagNameRepository,
		TagNameSharedRepo,
		TagNameSharedLocal,
		TagNameSharedGLobal}
}

type IngoreCallback = func(namespacePath string) (ignored bool)
type TrustCallback = func(hookPath string) (trusted bool, sha1 string)

func GetAllHooksIn(
	hooksDir string,
	hookName string,
	hookNamespace string,
	isIgnored IngoreCallback,
	isTrusted TrustCallback,
	lazyIfIgnored bool) (allHooks []Hook, err error) {

	appendHook := func(hookPath string, hookNamespace string) error {
		// Namespace the path to check ignores
		namespacedPath := path.Join(hookNamespace, path.Base(hookPath))
		ignored := isIgnored(namespacedPath)

		trusted := false
		sha := ""
		var runCmd cm.Executable

		if !ignored || !lazyIfIgnored {
			trusted, sha = isTrusted(hookPath)

			if runCmd, err = GetHookRunCmd(hookPath); err != nil {
				return cm.CombineErrors(err,
					cm.ErrorF("Could not detect runner for hook\n'%s'", hookPath))
			}
		}

		allHooks = append(allHooks,
			Hook{
				Executable:    runCmd,
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

				res[currIdx+idx].Output, err =
					cm.GetCombinedOutputFromExecutable(
						exec,
						&hooksGroup[idx],
						cm.UseOnlyStdin(os.Stdin),
						args...)

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
						cm.GetCombinedOutputFromExecutable(
							exec,
							hook,
							cm.UseOnlyStdin(os.Stdin), args...)

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
