package hooks

import (
	"io/ioutil"
	"path"
	"path/filepath"
	cm "rycus86/githooks/common"
	strs "rycus86/githooks/strings"
	"strings"

	glob "github.com/bmatcuk/doublestar/v3"
)

// HookIgnorePatterns is the format of the ignore patterns.
type HookIgnorePatterns struct {
	// Shell file patterns (uses `filepath.Match`) matching hook namespace paths.
	Patterns []string `yaml:"patterns"`
	// Specific hook namespace paths (uses full string match).
	NamespacePaths []string `yaml:"namespace-paths"`
}

// RepoIgnorePatterns is the list of possible ignore patterns in a repository.
type RepoIgnorePatterns struct {
	HooksDir HookIgnorePatterns // Ignores set by `.ignore` file in the hooks directory of the repository.
	User     HookIgnorePatterns // Ignores set by the `.ignore` file in the Git directory of the repository.
}

// CombineIgnorePatterns combines two ignore patterns.
func CombineIgnorePatterns(patterns ...HookIgnorePatterns) HookIgnorePatterns {
	var p HookIgnorePatterns
	for _, pat := range patterns {
		p.Add(pat)
	}

	return p
}

// AddPatterns adds pattern to the patterns.
func (h *HookIgnorePatterns) AddPatterns(pattern ...string) {
	h.Patterns = append(h.Patterns, pattern...)
}

// AddNamespacePaths adds a namespace path to the patterns.
func (h *HookIgnorePatterns) AddNamespacePaths(namespacePath ...string) {
	h.NamespacePaths = append(h.NamespacePaths, namespacePath...)
}

// Add adds pattern from other patterns to itself.
func (h *HookIgnorePatterns) Add(p HookIgnorePatterns) {
	h.Patterns = append(h.Patterns, p.Patterns...)
	h.NamespacePaths = append(h.NamespacePaths, p.NamespacePaths...)
}

// IsIgnored returns true if `NamespacePathspacePath` is ignored and otherwise `false`.
func (h *HookIgnorePatterns) IsIgnored(namespacePath string) bool {

	for _, p := range h.Patterns {
		// Note: Only forward slashes need to be used here in `hookPath`
		cm.DebugAssert(!strings.Contains(namespacePath, `\`),
			"Only forward slashes")

		matched, err := glob.Match(p, namespacePath)

		cm.DebugAssertNoErrorF(err, "List contains malformed pattern '%s'", p)
		if err == nil && matched {
			return true
		}
	}

	return strs.Includes(h.NamespacePaths, namespacePath)
}

// IsIgnored returns `true` if the hooksPath is ignored by either the worktree patterns or the user patterns
// and otherwise `false`. The second value is `true` if it was ignored by the user patterns.
func (h *RepoIgnorePatterns) IsIgnored(namespacePath string) (bool, bool) {
	if h.HooksDir.IsIgnored(namespacePath) {
		return true, false
	} else if h.User.IsIgnored(namespacePath) {
		return true, true
	}

	return false, false
}

// GetHookIgnorePatternsHookDir gets all ignored hooks in the current worktree.
func GetHookIgnorePatternsHookDir(repoHooksDir string, hookNames []string) (patterns HookIgnorePatterns, err error) {

	file := path.Join(repoHooksDir, ".ignore.yaml")
	if cm.IsFile(file) {
		patterns, err = loadIgnorePatterns(file)
	}

	for _, hookName := range hookNames {
		file = path.Join(repoHooksDir, hookName, ".ignore.yaml")

		if cm.IsFile(file) {
			ps, e := loadIgnorePatterns(file)
			err = cm.CombineErrors(err, e)
			patterns.Add(ps)
		}
	}

	if ReadLegacyIgnoreFiles {
		// Legacy load hooks from old ignore files
		// @todo Remove and only use the .yaml implementation.
		ps, e := loadIgnorePatternsLegacy(repoHooksDir, hookNames)
		err = cm.CombineErrors(err, e)
		patterns.Add(ps)
	}

	return
}

// GetHookIgnoreFileGitDir gets
// the file of all ignored hooks in the current Git directory.
func GetHookIgnoreFileGitDir(gitDir string) string {
	return path.Join(gitDir, ".githooks.ignore.yaml")
}

// getHookIgnorePatternsGitDir gets all ignored hooks in the current Git directory.
func getHookIgnorePatternsGitDir(gitDir string) (HookIgnorePatterns, error) {
	file := GetHookIgnoreFileGitDir(gitDir)
	exists, err := cm.IsPathExisting(file)
	if exists {
		return loadIgnorePatterns(file)
	}

	return HookIgnorePatterns{}, err
}

// StoreHookIgnorePatternsGitDir stores all ignored hooks in the current Git directory.
func StoreHookIgnorePatternsGitDir(patterns HookIgnorePatterns, gitDir string) error {
	return storeIgnorePatterns(patterns,
		path.Join(gitDir, ".githooks.ignore.yaml"))
}

// getHookIgnorePatternsLegacy loads file `.githooks.checksum` and parses "disabled>" entries
// @todo This needs to be deleted once the test work.
func getHookIgnorePatternsLegacy(gitDir string) (HookIgnorePatterns, error) {

	file := path.Join(gitDir, ".githooks.checksum")
	var p HookIgnorePatterns

	if cm.IsFile(file) {
		data, err := ioutil.ReadFile(file)
		if err != nil {
			return p, err
		}

		s := strs.SplitLines(string(data))

		for _, l := range s {
			l := strings.TrimSpace(l)
			if strings.HasPrefix(l, "disabled>") {
				hookPath := strings.TrimPrefix(l, "disabled>")
				p.NamespacePaths = append(p.NamespacePaths, path.Base(strings.TrimSpace(hookPath)))
			}
		}
	}

	return p, nil
}

// loadIgnorePatterns loads patterns.
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

// storeIgnorePatterns stores patterns.
func storeIgnorePatterns(patterns HookIgnorePatterns, file string) (err error) {
	return cm.StoreYAML(file, &patterns)
}

func loadIgnorePatternsLegacy(repoHooksDir string, hookNames []string) (patterns HookIgnorePatterns, err error) {

	file := path.Join(repoHooksDir, ".ignore")
	if cm.IsFile(file) {
		patterns, err = loadIgnorePatternsLegacyFile(file)
	}

	for _, hookName := range hookNames {
		file = path.Join(repoHooksDir, hookName, ".ignore")
		if cm.IsFile(file) {
			p, e := loadIgnorePatternsLegacyFile(file)
			err = cm.CombineErrors(err, e)
			patterns.Add(p)
		}
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
			if s == "" || strings.HasPrefix(s, "#") {
				continue
			}

			// We add '**/' to each pattern, as we no longer match filenames only
			// but a whole namespacePath.
			if ReadLegacyIgnoreFileFixPatters {
				s = "**/" + s
			}

			p.Patterns = append(p.Patterns, s)
		}
	}

	return
}

// GetIgnorePatterns loads all ignore patterns in the worktree's hooks dir and
// also in the Git directory.
func GetIgnorePatterns(repoHooksDir string, gitDir string, hookNames []string) (patt RepoIgnorePatterns, err error) {
	var e error

	patt.HooksDir, e = GetHookIgnorePatternsHookDir(repoHooksDir, hookNames)
	if e != nil {
		err = cm.CombineErrors(cm.Error("Could not get worktree ignore patterns."), e)
	}

	patt.User, e = getHookIgnorePatternsGitDir(gitDir)
	if e != nil {
		err = cm.CombineErrors(err, cm.Error("Could not get user ignore patterns."), e)
	}

	// Legacy
	// @todo Remove as soon as possible
	legacyDisabledHooks, e := getHookIgnorePatternsLegacy(gitDir)
	if e != nil {
		err = cm.CombineErrors(err, cm.Error("Could not get legacy ignore patterns."), e)
	}
	patt.User.Add(legacyDisabledHooks)

	return
}

// MakeNamespacePath makes `path` relative to `basePath` and adds `namespace/` as prefix if not empty.
func MakeNamespacePath(basePath string, path string, namespace string) (string, error) {
	s, err := filepath.Rel(basePath, path)
	if err != nil {
		return path, err
	}

	if namespace != "" {
		return namespace + "/" + filepath.ToSlash(s), nil
	}

	return filepath.ToSlash(s), nil
}
