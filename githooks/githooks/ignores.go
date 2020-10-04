package hooks

import (
	"path"
	cm "rycus86/githooks/common"
)

// HookIgnorePatterns is the format of the ignore patterns.
type HookIgnorePatterns struct {
	Patterns []string
}

// GetHookIgnorePatterns gets all ignored hooks in the current repository
func GetHookIgnorePatterns(repoDir string, gitDir string, hookName string) (HookIgnorePatterns, error) {

	var patterns1 HookIgnorePatterns
	var err1 error

	file := path.Join(repoDir, ".ignore")
	if cm.PathExists(file) {
		patterns1, err1 = loadIgnorePatterns(file)
	}

	file = path.Join(repoDir, hookName, ".ignore")
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
	err := cm.LoadJSON(file, &patterns)
	if err != nil {
		return patterns, err
	}
	return patterns, nil
}

// Combine combines two patterns.
func (h *HookIgnorePatterns) Combine(p HookIgnorePatterns) {
	h.Patterns = append(h.Patterns, p.Patterns...)
}
