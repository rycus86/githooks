package git

import (
	"os"
	"path/filepath"
	cm "rycus86/githooks/common"
	strs "rycus86/githooks/strings"
	"strings"

	"github.com/hashicorp/go-version"
)

const (
	// NullRef is the null reference used by git during certain hook execution.
	NullRef = "0000000000000000000000000000000000000000"
)

// IsBareRepo returns `true` if `path` is a bare repository.
func (c *Context) IsBareRepo() bool {
	out, _ := c.Get("rev-parse", "--is-bare-repository")
	return out == "true" //nolint:nlreturn
}

// IsGitRepo returns `true` if `path` is a git repository (bare or non-bare).
func (c *Context) IsGitRepo() bool {
	return c.Check("rev-parse") == nil
}

// GetGitCommonDir returns the common Git directory.
func (c *Context) GetGitCommonDir() (gitDir string, err error) {
	gitDir, err = c.Get("rev-parse", "--git-common-dir")
	if err != nil {
		return
	}

	gitDir, err = filepath.Abs(gitDir)
	if err != nil {
		return
	}

	gitDir = filepath.ToSlash(gitDir)

	return
}

// Clone an URL to a path `repoPath`.
func Clone(repoPath string, url string, branch string, depth int) error {
	args := []string{"clone", "-c", "core.hooksPath=", "--template=", "--single-branch"}

	if branch != "" {
		args = append(args, "--branch", branch)
	}

	if depth > 0 {
		args = append(args, strs.Fmt("--depth=%v", depth))
	}

	args = append(args, []string{url, repoPath}...)
	out, e := CtxSanitized().GetCombined(args...)

	if e != nil {
		return cm.ErrorF("Cloning of '%s'\ninto '%s' failed:\n%s", url, repoPath, out)
	}

	return nil
}

// Pull executes a pull in `repoPath`.
func (c *Context) Pull(remote string) error {
	out, e := c.GetCombined("pull", remote)
	if e != nil {
		return cm.ErrorF("Pulling '%s' in '%s' failed:\n%s", remote, c.Cwd, out)
	}

	return nil
}

// Fetch executes a fetch of a `branch` from the `remote` in `repoPath`.
func (c *Context) Fetch(remote string, branch string) error {
	out, e := c.GetCombined("fetch", remote, branch)
	if e != nil {
		return cm.ErrorF("Fetching of '%s' from '%s'\nin '%s' failed:\n%s", branch, remote, c.Cwd, out)
	}

	return nil
}

// GetCommits gets all commits in the ancestry path starting from `firstSHA` (excluded in the result)
// up to and including `lastSHA`.
func (c *Context) GetCommits(firstSHA string, lastSHA string) ([]string, error) {
	return c.GetSplit("rev-list", "--ancestry-path", strs.Fmt("%s..%s", firstSHA, lastSHA))
}

// GetCommitLog gets all commits in the ancestry path starting from `firstSHA` (excluded in the result)
// up to and including `lastSHA`.
func (c *Context) GetCommitLog(commitSHA string, format string) (string, error) {
	return c.Get("log", strs.Fmt("--format=%s", format), commitSHA)
}

// GetRemoteURLAndBranch reports the `remote`s `url` and
// the current `branch` of HEAD.
func (c *Context) GetRemoteURLAndBranch(remote string) (currentURL string, currentBranch string, err error) {
	currentURL = c.GetConfig("remote."+remote+".url", LocalScope)
	currentBranch, err = c.Get("symbolic-ref", "-q", "--short", HEAD)

	return
}

// PullOrClone either executes a pull in `repoPath` or if not
// existing, clones to this path.
func PullOrClone(
	repoPath string,
	url string,
	branch string,
	depth int,
	repoCheck func(*Context) error) (isNewClone bool, err error) {

	gitx := CtxCSanitized(repoPath)
	if gitx.IsGitRepo() {
		isNewClone = false

		if repoCheck != nil {
			if err = repoCheck(gitx); err != nil {
				return
			}
		}

		err = gitx.Pull("origin")
	} else {
		isNewClone = true

		if err = os.RemoveAll(repoPath); err != nil {
			err = cm.ErrorF("Could not remove directory '%s'.", repoPath)
			return //nolint:nlreturn
		}

		err = Clone(repoPath, url, branch, depth)
	}

	return
}

// RepoCheck is the function which is executed before a fetch.
// Arguments 1 and 2 are `url`, `branch`.
// Return an error to abort the action.
// Return `true` to trigger a complete reclone.
// Available ConfigScope's.
type RepoCheck = func(Context, string, string) (bool, error)

// FetchOrClone either executes a fetch in `repoPath` or if not
// existing, clones to this path.
// The callback `repoCheck` before a fetch can trigger a reclone.
func FetchOrClone(
	repoPath string,
	url string, branch string,
	depth int,
	repoCheck RepoCheck) (isNewClone bool, err error) {

	gitx := CtxCSanitized(repoPath)

	if gitx.IsGitRepo() {
		isNewClone = false

		if repoCheck != nil {
			reclone := false
			if reclone, err = repoCheck(*gitx, url, branch); err != nil {
				return
			}

			isNewClone = reclone
		}

	} else {
		isNewClone = true
	}

	if isNewClone {
		if err = os.RemoveAll(repoPath); err != nil {
			return
		}
		err = Clone(repoPath, url, branch, depth)
	} else {
		err = gitx.Fetch("origin", branch)
	}

	return
}

// GetSHA1HashFile gets the `git hash-object` SHA1 of a `path`.
func GetSHA1HashFile(path string) (string, error) {
	return Ctx().Get("hash-object", path)
}

// GetTags gets the tags  at `commitSHA`.
func GetTags(gitx *Context, commitSHA string) ([]string, error) {
	if strs.IsEmpty(commitSHA) {
		commitSHA = HEAD
	}

	return gitx.GetSplit("tag", "--points-at", commitSHA)
}

// GetVersionAt gets the version & tag from the tags at `commitSHA`.
func GetVersionAt(gitx *Context, commitSHA string) (*version.Version, string, error) {
	tags, err := GetTags(gitx, commitSHA)
	if err != nil {
		return nil, "", err
	}

	for _, tag := range tags {
		ver, err := version.NewVersion(tag)
		if err == nil && ver != nil {
			return ver, tag, nil
		}
	}

	return nil, "", nil
}

// GetVersion gets the semantic version and its tag.
func GetVersion(gitx *Context, commitSHA string) (v *version.Version, tag string, err error) {

	if commitSHA == HEAD {
		commitSHA, err = GetCommitSHA(gitx, HEAD)
		if err != nil {
			return
		}
	}

	tag, err = gitx.Get("describe", "--tags", "--abbrev=0", commitSHA)
	if err != nil {
		return
	}
	ver := tag

	// Get number of commits ahead.
	commitsAhead, err := gitx.Get("rev-list", "--count", strs.Fmt("%s..%s", ver, commitSHA))
	if err != nil {
		return
	}

	if commitsAhead != "0" {
		ver = strs.Fmt("%s+%s.%s", ver, commitsAhead, commitSHA[:7])
	}

	ver = strings.TrimPrefix(ver, "v")
	v, err = version.NewVersion(ver)

	return v, tag, err
}

// GetCommitSHA gets the commit SHA1 of the ref.
func GetCommitSHA(gitx *Context, ref string) (string, error) {
	if strs.IsEmpty(ref) {
		ref = HEAD
	}

	return gitx.Get("rev-parse", ref)
}
