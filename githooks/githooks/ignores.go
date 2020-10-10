package hooks

import (
	"path/filepath"
	cm "rycus86/githooks/common"
	strs "rycus86/githooks/strings"
)

// HookIgnorePatterns is the format of the ignore patterns.
type HookIgnorePatterns struct {
	Patterns  []string // Shell file patterns (see `filepath.Match`)
	HookNames []string // Specific hook names. @todo Introduce namespacing!
}

// IgnorePatterns is the list of possible ignore patterns when running a runner.
type IgnorePatterns struct {
	Worktree *HookIgnorePatterns
	User     *HookIgnorePatterns
}

// CombineIgnorePatterns combines two ignore patterns.
func CombineIgnorePatterns(patterns ...*HookIgnorePatterns) *HookIgnorePatterns {
	var pComb *HookIgnorePatterns
	for _, p := range patterns {
		if p != nil {
			if pComb == nil {
				pComb = p
			} else {
				pComb.Combine(*p)
			}

		}
	}
	return pComb
}

// GetHookIgnorePatternsWorktree gets all ignored hooks in the current worktree
func GetHookIgnorePatternsWorktree(repoDir string, hookName string) (patterns *HookIgnorePatterns, err error) {

	file := filepath.Join(repoDir, ".githooks", ".ignore.yaml")
	exists1, err := cm.PathExists(file)
	if exists1 {
		patterns, err = loadIgnorePatterns(file)
	}

	file = filepath.Join(repoDir, ".githooks", hookName, ".ignore.yaml")
	exists2, e := cm.PathExists(file)
	err = cm.CombineErrors(err, e)

	if exists2 {
		patterns2, e := loadIgnorePatterns(file)
		err = cm.CombineErrors(err, e)
		patterns = CombineIgnorePatterns(patterns, patterns2)
	}

	return
}

// GetHookIgnorePatterns gets all ignored hooks in the current Git directorys.
func GetHookIgnorePatterns(gitDir string) (*HookIgnorePatterns, error) {
	file := filepath.Join(gitDir, ".githooks.ignore.yaml")
	exists, err := cm.PathExists(file)
	if exists {
		return loadIgnorePatterns(file)
	}
	return nil, err
}

// LoadIgnorePatterns loads patterns.
func loadIgnorePatterns(file string) (*HookIgnorePatterns, error) {
	var patterns HookIgnorePatterns
	err := cm.LoadYAML(file, &patterns)
	if err != nil {
		return nil, err
	}

	// Filter all malformed patterns and report
	// errors.
	patternIsValid := func(p string) bool {
		if p == "" {
			return false
		}

		_, e := filepath.Match(p, "/test")
		err := cm.CombineErrors(err, e)
		return err == nil
	}
	patterns.Patterns = strs.Filter(patterns.Patterns, patternIsValid)

	return &patterns, err
}

// Combine combines two patterns.
func (h *HookIgnorePatterns) Combine(p HookIgnorePatterns) {
	h.Patterns = append(h.Patterns, p.Patterns...)
}

// IsIgnored returns true if `hookPath` is ignored and otherwise `false`
func (h *HookIgnorePatterns) IsIgnored(hookPath string) bool {

	for _, p := range h.Patterns {
		matched, err := filepath.Match(p, hookPath)
		cm.DebugAssertNoErrorF(err, "List contains malformed pattern '%s'", p)
		return err == nil && matched
	}

	return false
}

// IsIgnored returns `true` is ignored by either the worktree patterns or the user patterns
// and otherwise `false`. The second value is `true` if it was ignored by the user patterns.
func (h *IgnorePatterns) IsIgnored(hookPath string) (bool, bool) {
	if h.Worktree != nil && h.Worktree.IsIgnored(hookPath) {
		return true, false
	} else if h.User != nil && h.User.IsIgnored(hookPath) {
		return true, true
	}
	return false, false
}
