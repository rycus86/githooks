package hooks

import (
	"io/ioutil"
	"path"
	"path/filepath"
	cm "rycus86/githooks/common"
	strs "rycus86/githooks/strings"
	"strings"
)

// HookIgnorePatterns is the format of the ignore patterns.
type HookIgnorePatterns struct {
	Patterns  []string // Shell file patterns (see `filepath.Match`)
	HookNames []string // Specific hook names.
}

// RepoIgnorePatterns is the list of possible ignore patterns in a repository.
type RepoIgnorePatterns struct {
	Worktree HookIgnorePatterns // Ignores set by `.ignore` file in the repository.
	User     HookIgnorePatterns // Ignores set by the user of the repository.
}

// CombineIgnorePatterns combines two ignore patterns.
func CombineIgnorePatterns(patterns ...HookIgnorePatterns) HookIgnorePatterns {
	var p HookIgnorePatterns
	for _, pat := range patterns {
		p.Add(pat)
	}
	return p
}

// Add adds pattersn from other patterns to itself.
func (h *HookIgnorePatterns) Add(p HookIgnorePatterns) {
	h.Patterns = append(h.Patterns, p.Patterns...)
	h.HookNames = append(h.HookNames, p.HookNames...)
}

// IsIgnored returns true if `hookPath` is ignored and otherwise `false`
func (h *HookIgnorePatterns) IsIgnored(hookPath string) bool {

	// Legacy
	// @todo Remove only restricting to filename!
	hookPath = path.Base(hookPath)

	for _, p := range h.Patterns {
		matched, err := filepath.Match(p, hookPath)
		cm.DebugAssertNoErrorF(err, "List contains malformed pattern '%s'", p)
		return err == nil && matched
	}

	return strs.Includes(h.HookNames, hookPath)
}

// IsIgnored returns `true` if the hooksPath is ignored by either the worktree patterns or the user patterns
// and otherwise `false`. The second value is `true` if it was ignored by the user patterns.
func (h *RepoIgnorePatterns) IsIgnored(hookPath string) (bool, bool) {
	if h.Worktree.IsIgnored(hookPath) {
		return true, false
	} else if h.User.IsIgnored(hookPath) {
		return true, true
	}
	return false, false
}

// GetHookIgnorePatternsWorktree gets all ignored hooks in the current worktree
func GetHookIgnorePatternsWorktree(repoDir string, hookName string) (patterns HookIgnorePatterns, err error) {

	file := path.Join(repoDir, HookDirName, ".ignore.yaml")
	exists1, err := cm.IsPathExisting(file)
	if exists1 {
		patterns, err = loadIgnorePatterns(file)
	}

	file = path.Join(repoDir, HookDirName, hookName, ".ignore.yaml")
	exists2, e := cm.IsPathExisting(file)
	err = cm.CombineErrors(err, e)

	if exists2 {
		patterns2, e := loadIgnorePatterns(file)
		err = cm.CombineErrors(err, e)
		patterns.Add(patterns2)
	}

	// Legacy load hooks from old ignore files
	// @todo Remove and only use the .yaml implementation.
	patterns3, e := loadIgnorePatternsLegacy(repoDir, hookName)
	err = cm.CombineErrors(err, e)
	patterns.Add(patterns3)

	return
}

// GetHookIgnorePatternsGitDir gets all ignored hooks in the current Git directorys.
func GetHookIgnorePatternsGitDir(gitDir string) (HookIgnorePatterns, error) {

	file := path.Join(gitDir, ".githooks.ignore.yaml")
	exists, err := cm.IsPathExisting(file)
	if exists {
		return loadIgnorePatterns(file)
	}
	return HookIgnorePatterns{}, err
}

// GetHookIgnorePatternsLegacy loads file `.githooks.checksum` and parses "disabled>" entries
// @todo This needs to be deleted once the test work.
func GetHookIgnorePatternsLegacy(gitDir string) (HookIgnorePatterns, error) {

	data, err := ioutil.ReadFile(path.Join(gitDir, ".githooks.checksum"))
	if err == nil {
		var p HookIgnorePatterns

		s := strs.SplitLines(string(data))

		for _, l := range s {
			l := strings.TrimSpace(l)
			if strings.HasPrefix(l, "disabled>") {
				hookPath := strings.TrimPrefix(l, "disabled>")
				p.HookNames = append(p.HookNames, path.Base(strings.TrimSpace(hookPath)))
			}
		}

		return p, nil
	}
	return HookIgnorePatterns{}, err
}

// LoadIgnorePatterns loads patterns.
func loadIgnorePatterns(file string) (patterns HookIgnorePatterns, err error) {
	err = cm.LoadYAML(file, &patterns)
	if err != nil {
		return
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

	return
}

func loadIgnorePatternsLegacy(repoDir string, hookName string) (patterns HookIgnorePatterns, err error) {

	file := path.Join(repoDir, HookDirName, ".ignore")
	exists1, err := cm.IsPathExisting(file)
	if exists1 {
		patterns, err = loadIgnorePatternsLegacyFile(file)
	}

	file = path.Join(repoDir, HookDirName, hookName, ".ignore")
	exists2, e := cm.IsPathExisting(file)
	err = cm.CombineErrors(err, e)

	if exists2 {
		patterns2, e := loadIgnorePatternsLegacyFile(file)
		err = cm.CombineErrors(err, e)
		patterns.Add(patterns2)
	}
	return
}

func loadIgnorePatternsLegacyFile(file string) (p HookIgnorePatterns, err error) {

	exists, e := cm.IsPathExisting(file)
	err = cm.CombineErrors(err, e)
	if exists {
		data, e := ioutil.ReadFile(file)
		err = cm.CombineErrors(err, e)

		for _, s := range strs.SplitLines(string(data)) {
			if s != "" || !strings.HasPrefix(s, "#") {
				p.Patterns = append(p.Patterns, s)
			}
		}
	}
	return
}
