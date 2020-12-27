package hooks

import (
	"io/ioutil"
	"path"
	"regexp"
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"
	strs "rycus86/githooks/strings"
	"strings"
)

// SharedHook is the data for a shared hook.
type SharedHook struct {
	OriginalURL string

	IsCloned bool
	URL      string
	Branch   string

	IsLocal bool

	RootDir string
}

// GetRepoSharedFile gets the shared file with respect to the hooks dir in the repository.
func GetRepoSharedFile(repoHooksDir string) string {
	return path.Join(repoHooksDir, ".shared")
}

// SharedConfigName defines the config name used to define local/global
// shared hooks in the local/global Git configuration.
var SharedConfigName string = "githooks.shared"
var reEscapeURL = regexp.MustCompile(`[^a-zA-Z0-9]+`)

// GetSharedDir gets the shared directory where all shared clone reside inside the install dir.
func GetSharedDir(installDir string) string {
	return path.Join(installDir, "shared")
}

func getSharedCloneDir(installDir string, entry string) string {
	// Legacy: As we used `git hash-object --stdin` we need to model the same behavior here
	// @todo Remove `blob`+ length + \0...
	sha1 := cm.GetSHA1HashString("blob ", strs.Fmt("%v", len([]byte(entry))), "\u0000", entry)

	name := []rune(entry)
	if len(entry) > 48 { // nolint:gomnd
		name = name[0:48]
	}
	nameAbrev := reEscapeURL.ReplaceAllLiteralString(string(name), "-")

	return path.Join(GetSharedDir(installDir), sha1+"-"+nameAbrev)
}

var reURLScheme *regexp.Regexp = regexp.MustCompile(`(?m)^[^:/?#]+://`)
var reShortSCPSyntax = regexp.MustCompile(`(?m)^.+@.+:.+`)
var reFileURLScheme = regexp.MustCompile(`(?m)^file://`)

func isSharedEntryALocalPath(url string) bool {
	return !(reURLScheme.MatchString(url) || reShortSCPSyntax.MatchString(url))
}

func isSharedEntryALocalURL(url string) bool {
	return reFileURLScheme.MatchString(url)
}

func parseSharedEntry(installDir string, entry string) (SharedHook, error) {

	h := SharedHook{IsCloned: true, IsLocal: false, OriginalURL: entry}
	doSplit := true

	if isSharedEntryALocalPath(entry) {

		h.IsLocal = true

		if git.CtxC(entry).IsBareRepo() {
			doSplit = false
		} else {
			// We have a local path to a non-bare repo
			h.IsCloned = false
			h.RootDir = entry
		}

	} else if isSharedEntryALocalURL(entry) {
		h.IsLocal = true
	}

	if h.IsCloned {
		// Here we now have a supported Git URL or
		// a local bare-repo `<localpath>`

		// Split "...@(.*)"
		if doSplit && strings.ContainsAny(entry, "@") {
			lastIdx := strings.LastIndexAny(entry, "@")
			if lastIdx > 0 {
				h.URL = entry[:lastIdx]
				h.Branch = entry[lastIdx:]
			}
		} else {
			h.URL = entry
		}

		// Define the shared clone folder
		h.RootDir = getSharedCloneDir(installDir, entry)
	}

	return h, nil
}

func parseData(installDir string, data string) (hooks []SharedHook, err error) {
	for _, line := range strs.SplitLines(data) {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		hook, e := parseSharedEntry(installDir, line)
		err = cm.CombineErrors(err, e)

		if e == nil {
			hooks = append(hooks, hook)
		}
	}

	return
}

// LoadRepoSharedHooks gets all shared hooks that reside inside `${repoHooksDir}/.shared`
// No checks are made to the filesystem if paths are existing in `SharedHook`.
func LoadRepoSharedHooks(installDir string, repoHooksDir string) (hooks []SharedHook, err error) {
	file := GetRepoSharedFile(repoHooksDir)
	exists, err := cm.IsPathExisting(file)

	if exists {
		data, e := ioutil.ReadFile(file)
		err = cm.CombineErrors(err, e)
		hooks, e = parseData(installDir, string(data))
		err = cm.CombineErrors(err, e)
	}

	return
}

// LoadConfigSharedHooks gets all shared hooks that are specified in
// the local/global Git configuration.
// No checks are made to the filesystem if paths are existing in `SharedHook`.
func LoadConfigSharedHooks(installDir string, ctx *git.Context, scope git.ConfigScope) (hooks []SharedHook, err error) {
	data := ctx.GetConfigAllU(SharedConfigName, scope)
	if data != "" {
		hooks, err = parseData(installDir, data)
	}

	return
}
