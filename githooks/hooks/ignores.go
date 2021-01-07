package hooks

import (
	"io/ioutil"
	"path"
	"path/filepath"
	cm "rycus86/githooks/common"
	strs "rycus86/githooks/strings"
	"strings"
)

// hookIgnoreFile is the format of the ignore patterns file.
// A path is ignored if matched by `Patterns` or `NamespacePaths`.
type hookIgnoreFile struct {
	// Git ignores patterns matching hook namespace paths.
	Patterns []string `yaml:"patterns"`
	// Specific hook namespace paths (uses full match).
	NamespacePaths []string `yaml:"namespace-paths"`

	// The version of the file.
	Version int `yaml:"version"`
}

// hookIngoreFileVersion is the ignore file version.
var hookIngoreFileVersion = 0

// HookPatterns for matching the namespace path of hooks.
type HookPatterns struct {
	Patterns       []string
	NamespacePaths []string
}

// RepoIgnorePatterns is the list of possible ignore patterns in a repository.
type RepoIgnorePatterns struct {
	HooksDir HookPatterns // Ignores set by `.ignore` file in the hooks directory of the repository.
	User     HookPatterns // Ignores set by the `.ignore` file in the Git directory of the repository.
}

// CombineIgnorePatterns combines two ignore patterns.
func CombineIgnorePatterns(patterns ...*HookPatterns) HookPatterns {
	var p HookPatterns
	for _, pat := range patterns {
		p.Add(pat)
	}

	return p
}

// GetCount gets the count of all patterns.
func (h *HookPatterns) GetCount() int {
	return len(h.Patterns) + len(h.NamespacePaths)
}

// AddPatterns adds pattern to the patterns.
func (h *HookPatterns) AddPatterns(pattern ...string) {
	h.Patterns = append(h.Patterns, pattern...)
}

// AddNamespacePathsUnique adds a namespace path to the patterns.
func (h *HookPatterns) AddPatternsUnique(pattern ...string) (added int) {
	h.Patterns, added = strs.AppendUnique(h.Patterns, pattern...)

	return
}

// AddNamespacePaths adds a namespace path to the patterns.
func (h *HookPatterns) AddNamespacePaths(namespacePath ...string) {
	h.NamespacePaths = append(h.NamespacePaths, namespacePath...)
}

// AddNamespacePathsUnique adds a namespace path to the patterns.
func (h *HookPatterns) AddNamespacePathsUnique(namespacePath ...string) (added int) {
	h.NamespacePaths, added = strs.AppendUnique(h.NamespacePaths, namespacePath...)

	return
}

// RemovePatterns removes patterns from the list.
func (h *HookPatterns) RemovePatterns(pattern ...string) (removed int) {
	c := 0

	for _, p := range pattern {
		h.Patterns, c = strs.Remove(h.Patterns, p)
		removed += c
	}

	return
}

// RemoveNamespacePaths adds a namespace path to the patterns.
func (h *HookPatterns) RemoveNamespacePaths(namespacePath ...string) (removed int) {
	c := 0
	for _, p := range namespacePath {
		h.NamespacePaths, c = strs.Remove(h.NamespacePaths, p)
		removed += c
	}

	return
}

// Add adds pattern from patterns `p` to itself.
func (h *HookPatterns) Add(p *HookPatterns) {
	h.AddPatterns(p.Patterns...)
	h.AddNamespacePaths(p.NamespacePaths...)
}

// AddUnique adds pattern uniquely from patterns `p` to itself.
func (h *HookPatterns) AddUnique(p *HookPatterns) (added int) {
	added = h.AddPatternsUnique(p.Patterns...)
	added += h.AddNamespacePathsUnique(p.NamespacePaths...)

	return
}

// Remove removes pattern from patterns `p` to itself.
func (h *HookPatterns) Remove(p *HookPatterns) (removed int) {
	removed = h.RemovePatterns(p.Patterns...)
	removed += h.RemoveNamespacePaths(p.NamespacePaths...)

	return
}

// RemoveAll removes all patterns.
func (h *HookPatterns) RemoveAll() (removed int) {
	removed = len(h.Patterns) + len(h.NamespacePaths)
	h.Patterns = nil
	h.NamespacePaths = nil

	return
}

// Reserve reserves 'nPatterns'.
func (h *HookPatterns) Reseve(nPatterns int) {
	if h.Patterns == nil {
		h.Patterns = make([]string, 0, nPatterns)
	}

	if h.NamespacePaths == nil {
		h.NamespacePaths = make([]string, 0, nPatterns)
	}
}

// checkPatternInversion checks a pattern for inversion prefix "!".
func checkPatternInversion(p string) (string, bool) {

	if strings.HasPrefix(p, "!") {
		return p[1:], true
	} else if strings.HasPrefix(p, `\!`) {
		return p[2:], false
	}

	return p, false
}

// Match returns true if `namespacePath` matches any of the patterns and otherwise `false`.
func (h *HookPatterns) Matches(namespacePath string) (matched bool) {

	for _, p := range h.Patterns {

		// Note: Only forward slashes need to be used here in `hookPath`
		cm.DebugAssert(!strings.Contains(namespacePath, `\`),
			"Only forward slashes")

		rawP, inverted := checkPatternInversion(p)

		// If we currently have a match, only an inversion can revert this...
		// so skip until we find an inversion.
		if matched && !inverted {
			continue
		}

		isMatch, err := cm.GlobMatch(rawP, namespacePath)
		cm.DebugAssertNoErrorF(err, "List contains malformed pattern '%s'", p)
		if err != nil {
			continue
		}

		if inverted {
			matched = matched && !isMatch
		} else {
			matched = matched || isMatch
		}
	}

	// The full matches can only change the result to `true`
	// They have no invertion "!" prefix.
	matched = matched || strs.Includes(h.NamespacePaths, namespacePath)

	return
}

// IsEmpty checks if there are any patterns stored.
func (h *HookPatterns) IsEmpty() bool {
	return len(h.Patterns)+len(h.NamespacePaths) == 0
}

// IsIgnored returns `true` if the hooksPath is ignored by either the worktree patterns or the user patterns
// and otherwise `false`. The second value is `true` if it was ignored by the user patterns.
func (h *RepoIgnorePatterns) IsIgnored(namespacePath string) (bool, bool) {
	if h.HooksDir.Matches(namespacePath) {
		return true, false
	} else if h.User.Matches(namespacePath) {
		return true, true
	}

	return false, false
}

// GetHookIgnoreFilesHooksDir gets ignores files inside the hook directory.
// The `hookName` can be empty.
func GetHookIngoreFileHooksDir(repoHooksDir string, hookName string) string {
	return path.Join(repoHooksDir, hookName, ".ignore.yaml")
}

// GetHookIgnoreFilesHooksDir gets ignores files inside the hook directory.
func GetHookIgnoreFilesHooksDir(repoHooksDir string, hookNames []string) (files []string) {
	files = make([]string, 0, 1+len(hookNames))

	files = append(files, GetHookIngoreFileHooksDir(repoHooksDir, ""))
	for _, hookName := range hookNames {
		files = append(files, GetHookIngoreFileHooksDir(repoHooksDir, hookName))
	}

	return
}

// GetHookPatternsHooksDir gets all ignored hooks in the hook directory.
func GetHookPatternsHooksDir(repoHooksDir string, hookNames []string) (patterns HookPatterns, err error) {
	files := GetHookIgnoreFilesHooksDir(repoHooksDir, hookNames)
	patterns.Reseve(2 * len(files)) // nolint: gomnd

	for _, file := range files {
		if cm.IsFile(file) {
			ps, e := LoadIgnorePatterns(file)
			err = cm.CombineErrors(err, e)
			patterns.Add(&ps)
		}
	}

	if ReadLegacyIgnoreFiles {
		// Legacy load hooks from old ignore files
		// @todo Remove and only use the .yaml implementation.
		ps, e := loadIgnorePatternsLegacy(repoHooksDir, hookNames)
		err = cm.CombineErrors(err, e)
		patterns.Add(&ps)
	}

	return
}

// GetHookIgnoreFileGitDir gets
// the file of all ignored hooks in the current Git directory.
func GetHookIgnoreFileGitDir(gitDir string) string {
	return path.Join(gitDir, ".githooks.ignore.yaml")
}

// getHookPatternsGitDir gets all ignored hooks in the current Git directory.
func getHookPatternsGitDir(gitDir string) (HookPatterns, error) {
	file := GetHookIgnoreFileGitDir(gitDir)
	exists, err := cm.IsPathExisting(file)
	if exists {
		return LoadIgnorePatterns(file)
	}

	return HookPatterns{}, err
}

// StoreHookPatternsGitDir stores all ignored hooks in the current Git directory.
func StoreHookPatternsGitDir(patterns HookPatterns, gitDir string) error {
	return StoreIgnorePatterns(patterns,
		path.Join(gitDir, ".githooks.ignore.yaml"))
}

// getHookPatternsLegacy loads file `.githooks.checksum` and parses "disabled>" entries
// @todo This needs to be deleted once the test work.
func getHookPatternsLegacy(gitDir string) (HookPatterns, error) {

	file := path.Join(gitDir, ".githooks.checksum")
	var p HookPatterns

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
func LoadIgnorePatterns(file string) (patterns HookPatterns, err error) {
	var data hookIgnoreFile

	err = cm.LoadYAML(file, &data)
	if err != nil {
		return
	}

	patterns.Patterns = data.Patterns
	patterns.NamespacePaths = data.NamespacePaths

	// Filter all malformed patterns and report
	// errors.
	patternIsValid := func(p string) (valid bool) {
		if valid = IsHookPatternValid(p); !valid {
			err = cm.CombineErrors(err, cm.ErrorF("Pattern '%s' is malformed.", p))
		}

		return
	}

	patterns.Patterns = strs.Filter(patterns.Patterns, patternIsValid)

	return
}

// IsHookPatternValid validates a ignore `pattern`.
// This test supports `globstar` syntax.
func IsHookPatternValid(pattern string) bool {
	if pattern == "" {
		return false
	}
	_, e := cm.GlobMatch(pattern, "/test")

	return e == nil
}

// StoreIgnorePatterns stores patterns.
func StoreIgnorePatterns(patterns HookPatterns, file string) (err error) {

	data := hookIgnoreFile{
		Version:        hookIngoreFileVersion,
		Patterns:       strs.MakeUnique(patterns.Patterns),
		NamespacePaths: strs.MakeUnique(patterns.NamespacePaths)}

	return cm.StoreYAML(file, &data)
}

func loadIgnorePatternsLegacy(repoHooksDir string, hookNames []string) (patterns HookPatterns, err error) {

	file := path.Join(repoHooksDir, ".ignore")
	if cm.IsFile(file) {
		patterns, err = loadIgnorePatternsLegacyFile(file)
	}

	for _, hookName := range hookNames {
		file = path.Join(repoHooksDir, hookName, ".ignore")
		if cm.IsFile(file) {
			p, e := loadIgnorePatternsLegacyFile(file)
			err = cm.CombineErrors(err, e)
			patterns.Add(&p)
		}
	}

	return
}

func loadIgnorePatternsLegacyFile(file string) (p HookPatterns, err error) {

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

	patt.HooksDir, e = GetHookPatternsHooksDir(repoHooksDir, hookNames)
	if e != nil {
		err = cm.CombineErrors(cm.Error("Could not get worktree ignore patterns."), e)
	}

	patt.User, e = getHookPatternsGitDir(gitDir)
	if e != nil {
		err = cm.CombineErrors(err, cm.Error("Could not get user ignore patterns."), e)
	}

	// Legacy
	// @todo Remove as soon as possible
	legacyDisabledHooks, e := getHookPatternsLegacy(gitDir)
	if e != nil {
		err = cm.CombineErrors(err, cm.Error("Could not get legacy ignore patterns."), e)
	}
	patt.User.Add(&legacyDisabledHooks)

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
