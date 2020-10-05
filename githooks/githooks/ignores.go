package hooks

import (
	"path"
	"path/filepath"
	cm "rycus86/githooks/common"
	strs "rycus86/githooks/strings"
)

// HookIgnorePatterns is the format of the ignore patterns.
type HookIgnorePatterns struct {
	Patterns []string
}

// GetHookIgnorePatterns gets all ignored hooks in the current repository
func GetHookIgnorePatterns(repoDir string, gitDir string, hookName string) (HookIgnorePatterns, error) {

	var patterns1 HookIgnorePatterns
	var err1 error

	file := path.Join(repoDir, ".githooks", ".ignore.yaml")
	if cm.PathExists(file) {
		patterns1, err1 = loadIgnorePatterns(file)
	}

	file = path.Join(repoDir, ".githooks", hookName, ".ignore.yaml")
	if cm.PathExists(file) {
		patterns2, err2 := loadIgnorePatterns(file)
		if err2 != nil {
			patterns1.Combine(patterns2)
		}
		cm.CombineErrors(err1, err2)
	}

	return patterns1, err1
}

// LoadIgnorePatterns loads patterns.
func loadIgnorePatterns(file string) (HookIgnorePatterns, error) {
	var patterns HookIgnorePatterns

	err := cm.LoadYAML(file, &patterns)
	if err != nil {
		return patterns, err
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

	return patterns, err
}

// Combine combines two patterns.
func (h *HookIgnorePatterns) Combine(p HookIgnorePatterns) {
	h.Patterns = append(h.Patterns, p.Patterns...)
}

// Matches returns true if `hookPath` matches any of the patterns and otherwise `false`
func (h *HookIgnorePatterns) Matches(hookPath string) bool {

	for _, p := range h.Patterns {
		matched, err := filepath.Match(p, hookPath)
		cm.DebugAssertF(err != nil, "List contains malformed pattern '%s'", p)
		return err == nil && matched
	}

	return false
}
