package hooks

import (
	"os"
	"path"
	"regexp"
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"
	strs "rycus86/githooks/strings"
	"strings"
)

// SharedHook is the data for a shared hook.
type SharedHook struct {
	OriginalURL string // Original URL.

	IsCloned bool   // If the repo needs to be cloned.
	URL      string // The clone URL.
	Branch   string // The clone branch.

	IsLocal bool // If the original URL points to a local directory.

	RepositoryDir string // The shared hook repository directory.
}

// SharedHookEnum is the enum type of the shared hook type.
type SharedHookEnum = int
type sharedHookEnum struct {
	Repo   SharedHookEnum
	Local  SharedHookEnum
	Global SharedHookEnum
}

// SharedHookEnum enumerates all types of shared hooks.
var SharedHookEnumV = &sharedHookEnum{Repo: 0, Local: 1, Global: 2} // nolint:gomnd

// sharedHookConfig is the format of the shared repositories config file.
type sharedHookConfig struct {
	// Version for the shared file.
	Version int `yaml:"version"`
	// Urls for shared repositories.
	Urls []string `yaml:"urls"`
}

const sharedHookConfigVersion int = 0

func createSharedHookConfig() sharedHookConfig {
	return sharedHookConfig{Version: sharedHookConfigVersion}
}

func loadRepoSharedHooks(file string) (sharedHookConfig, error) {
	var config = createSharedHookConfig()
	var err error

	if cm.IsFile(file) {
		err = cm.LoadYAML(file, &config)
	}

	config.Urls = strs.MakeUnique(config.Urls)

	return config, err
}

func saveRepoSharedHooks(file string, config *sharedHookConfig) error {
	err := os.MkdirAll(path.Dir(file), cm.DefaultFileModeDirectory)
	if err != nil {
		return err
	}

	return cm.StoreYAML(file, &config)
}

func saveLegacyRepoSharedHooks(file string, config *sharedHookConfig) error {
	err := os.MkdirAll(path.Dir(file), cm.DefaultFileModeDirectory)
	if err != nil {
		return err
	}

	f, err := os.Create(file)
	if err != nil {
		return err
	}

	defer f.Close()
	_ = f.Chmod(cm.DefaultFileModeFile)

	for _, url := range config.Urls {
		_, _ = f.WriteString(url + "\n")
	}

	return nil
}

// SharedConfigName defines the config name used to define local/global
// shared hooks in the local/global Git configuration.
var reEscapeURL = regexp.MustCompile(`[^a-zA-Z0-9]+`)

// GetSharedDir gets the shared directory where all shared clone reside inside the install dir.
func GetSharedDir(installDir string) string {
	return path.Join(installDir, "shared")
}

// GetRepoSharedFile gets the shared file with respect to the hooks dir in the repository.
func GetRepoSharedFile(repoDir string) string {
	return path.Join(GetGithooksDir(repoDir), ".shared.yaml")
}

// GetRepoSharedFile gets the shared file with respect to the hooks dir in the repository.
func getRepoSharedFileLegacy(repoDir string) string {
	return path.Join(GetGithooksDir(repoDir), ".shared")
}

// GetRepoSharedFile gets the shared file with respect to the repository.
func GetRepoSharedFileRel() string {
	return path.Join(HooksDirName, ".shared.yaml")
}

func GetSharedCloneDir(installDir string, url string) string {
	// Legacy: As we used `git hash-object --stdin` we need to model the same behavior here
	// @todo Remove `blob`+ length + \0...
	sha1 := cm.GetSHA1HashString("blob ", strs.Fmt("%v", len([]byte(url))), "\u0000", url)

	name := []rune(url)
	if len(url) > 48 { // nolint:gomnd
		name = name[0:48]
	}
	nameAbrev := reEscapeURL.ReplaceAllLiteralString(string(name), "-")

	return path.Join(GetSharedDir(installDir), sha1+"-"+nameAbrev)
}

var reURLScheme *regexp.Regexp = regexp.MustCompile(`(?m)^[^:/?#]+://`)
var reShortSCPSyntax = regexp.MustCompile(`(?m)^.+@.+:.+`)
var reFileURLScheme = regexp.MustCompile(`(?m)^file://`)

func isSharedUrlALocalPath(url string) bool {
	return !(reURLScheme.MatchString(url) || reShortSCPSyntax.MatchString(url))
}

func isSharedUrlALocalURL(url string) bool {
	return reFileURLScheme.MatchString(url)
}

func parseSharedUrl(installDir string, url string) (SharedHook, error) {

	h := SharedHook{IsCloned: true, IsLocal: false, OriginalURL: url}
	doSplit := true

	if isSharedUrlALocalPath(url) {

		h.IsLocal = true

		if git.CtxC(url).IsBareRepo() {
			doSplit = false
		} else {
			// We have a local path to a non-bare repo
			h.IsCloned = false
			h.RepositoryDir = url
		}

	} else if isSharedUrlALocalURL(url) {
		h.IsLocal = true
	}

	if h.IsCloned {
		// Here we now have a supported Git URL or
		// a local bare-repo `<localpath>`

		// Split "...@(.*)"
		if doSplit && strings.ContainsAny(url, "@") {
			lastIdx := strings.LastIndexAny(url, "@")
			if lastIdx > 0 {
				h.URL = url[:lastIdx]
				h.Branch = url[lastIdx+1:]
			}
		} else {
			h.URL = url
		}

		// Define the shared clone folder
		h.RepositoryDir = GetSharedCloneDir(installDir, url)
	}

	return h, nil
}

func parseData(installDir string, config *sharedHookConfig) (hooks []SharedHook, err error) {

	for _, url := range config.Urls {

		if strs.IsEmpty(url) {
			continue
		}

		hook, e := parseSharedUrl(installDir, url)
		if e == nil {
			hooks = append(hooks, hook)
		}

		err = cm.CombineErrors(err, e)
	}

	return
}

// AddUrl adds an url to the config.
func (c *sharedHookConfig) AddUrl(url string) (added bool) {
	c.Urls, added = strs.AppendUnique(c.Urls, url)

	return
}

// RemoveUrl removes an url from the config.
func (c *sharedHookConfig) RemoveUrl(url string) (removed bool) {
	c.Urls, removed = strs.Remove(c.Urls, url)

	return
}

func loadConfigSharedHooks(gitx *git.Context, scope git.ConfigScope) sharedHookConfig {
	config := createSharedHookConfig()
	data := gitx.GetConfigAllU(GitCK_Shared, scope)

	if strs.IsNotEmpty(data) {
		config = createSharedHookConfig()
		config.Urls = strs.MakeUnique(strs.SplitLines(data))
	}

	return config
}

func saveConfigSharedHooks(gitx *git.Context, scope git.ConfigScope, config *sharedHookConfig) error {
	// Remove all settings and add them back.
	if err := gitx.UnsetConfig(GitCK_Shared, scope); err != nil {
		return err
	}

	for _, url := range config.Urls {
		if e := gitx.AddConfig(GitCK_Shared, url, scope); e != nil {
			return cm.CombineErrors(e,
				cm.ErrorF("Could not add back all %s shared repository urls: '%q'", scope, config.Urls))
		}
	}

	return nil
}

// LoadConfigSharedHooks gets all shared hooks that are specified in
// the local/global Git configuration.
// No checks are made to the filesystem if paths are existing in `SharedHook`.
func LoadConfigSharedHooks(
	installDir string,
	gitx *git.Context,
	scope git.ConfigScope) (hooks []SharedHook, err error) {

	config := loadConfigSharedHooks(gitx, scope)

	return parseData(installDir, &config)
}

// LoadRepoSharedHooks gets all shared hooks that reside inside `hooks.GetRepoSharedFileRel()`
// No checks are made to the filesystem if paths are existing in `SharedHook`.
func LoadRepoSharedHooks(installDir string, repoDir string) (hooks []SharedHook, err error) {
	file := GetRepoSharedFile(repoDir)

	if !cm.IsFile(file) {
		return
	}

	config, err := loadRepoSharedHooks(file)
	if err != nil {
		return
	}

	hooks, err = parseData(installDir, &config)

	return
}

// ModifyRepoSharedHooks adds/removes a URL to the repository shared hooks.
func ModifyRepoSharedHooks(repoDir string, url string, remove bool) (modified bool, err error) {
	file := GetRepoSharedFile(repoDir)

	// Try parse it...
	h, err := parseSharedUrl("unneeded", url) // we dont need the install dir...
	if err != nil {
		err = cm.CombineErrors(err, cm.ErrorF("Cannot parse url '%s'.", url))

		return
	}

	// Safeguard if we want to add a local URL which does not make sense.
	if !remove && h.IsLocal && !AllowLocalURLInRepoSharedHooks() {
		err = cm.ErrorF("You cannot add a URL '%s'\n"+
			"pointing to a local directory to '%s'.",
			url, GetRepoSharedFileRel())

		return
	}

	config, err := loadRepoSharedHooks(file)

	if err != nil {
		return
	}

	if remove {
		modified = config.RemoveUrl(url)
	} else {
		modified = config.AddUrl(url)
	}

	// @todo remove as soon as possible
	_ = saveLegacyRepoSharedHooks(getRepoSharedFileLegacy(repoDir), &config)

	return modified, saveRepoSharedHooks(file, &config)
}

// ModifyRepoSharedHooks adds/removes a URL to the local shared hooks.
func ModifyLocalSharedHooks(gitx *git.Context, url string, remove bool) (modified bool, err error) {
	config := loadConfigSharedHooks(gitx, git.LocalScope)

	if remove {
		modified = config.RemoveUrl(url)
	} else {
		modified = config.AddUrl(url)
	}

	err = saveConfigSharedHooks(gitx, git.LocalScope, &config)

	return
}

// ModifyRepoSharedHooks adds/removes a URL to the global shared hooks.
func ModifyGlobalSharedHooks(gitx *git.Context, url string, remove bool) (modified bool, err error) {
	config := loadConfigSharedHooks(gitx, git.GlobalScope)

	if remove {
		modified = config.RemoveUrl(url)
	} else {
		modified = config.AddUrl(url)
	}

	err = saveConfigSharedHooks(gitx, git.GlobalScope, &config)

	return
}

// UpdateSharedHooks updates all shared hooks `sharedHooks`.
// It clones or pulls latest changes in the shared clones. The `log` can be nil.
func UpdateSharedHooks(
	log cm.ILogContext,
	sharedHooks []SharedHook,
	sharedType SharedHookEnum) (updateCount int, err error) {

	for _, hook := range sharedHooks {

		if !hook.IsCloned {
			continue

		} else if !AllowLocalURLInRepoSharedHooks() &&
			sharedType == SharedHookEnumV.Repo && hook.IsLocal {

			if log != nil {
				log.WarnF("Shared hooks in '%[1]s' contain a local path\n"+
					"'%[2]s'\n"+
					"which is forbidden. Update will be skipped.\n\n"+
					"You can only have local paths for shared hooks defined\n"+
					"in the local or global Git configuration.\n\n"+
					"This can be achieved by running\n"+
					"  $ git hooks shared add [--local|--global] '%[2]s'\n"+
					"and deleting it from the '%[3]s' file manually by\n"+
					"  $ git hooks shared remove --shared '%[2]s'\n",
					GetRepoSharedFileRel(), hook.OriginalURL, GetRepoSharedFileRel())
			}

			continue
		}

		if log != nil {
			log.InfoF("Updating shared hooks from: '%s'", hook.OriginalURL)
		}

		depth := -1
		if hook.IsLocal {
			depth = 1
		}

		_, e := git.PullOrClone(hook.RepositoryDir, hook.URL, hook.Branch, depth, nil)
		err = cm.CombineErrors(err, e)

		if log != nil && e != nil {
			log.ErrorF("Updating hooks '%s' failed.", hook.OriginalURL)
		}

		updateCount += 1
	}

	return
}

// Purge all shared hook repositories.
func PurgeSharedDir(installDir string) error {
	dir := GetSharedDir(installDir)

	return os.RemoveAll(dir)
}

// ClearRepoSharedHooks clears the shared hook list in the repository.
func ClearRepoSharedHooks(repoDir string) error {
	file := GetRepoSharedFile(repoDir)
	if !cm.IsFile(file) {
		return nil
	}

	f, err := os.Create(file)
	if err != nil {
		return err
	}

	return f.Chmod(cm.DefaultFileModeFile)
}

// ClearLocalSharedHooks clears the shared hook list in the local Git config.
func ClearLocalSharedHooks(gitx *git.Context) error {
	return gitx.UnsetConfig(GitCK_Shared, git.LocalScope)
}

// ClearLocalSharedHooks clears the shared hook list in the global Git config.
func ClearGlobalSharedHooks() error {
	return git.Ctx().UnsetConfig(GitCK_Shared, git.GlobalScope)
}

// GetSharedHookTypeString translates the shared type enum to a string.
func GetSharedHookTypeString(sharedType SharedHookEnum) string {
	switch sharedType {
	case SharedHookEnumV.Repo:
		return "repo"
	case SharedHookEnumV.Local:
		return "local"
	case SharedHookEnumV.Global:
		return "global"
	default:
		cm.DebugAssertF(false, "Wrong type '%s'", sharedType)

		return "wrong-value" // nolint:nlreturn
	}
}

// IsCloneValid checks if the cloned shared hook repository is valid,
// contains the same remote URL as the requested.
func (s *SharedHook) IsCloneValid() bool {
	if s.IsCloned {
		return git.CtxC(s.RepositoryDir).GetConfig("remote.origin.url", git.LocalScope) == s.URL
	} else {
		cm.DebugAssert(false)

		return false
	}
}
