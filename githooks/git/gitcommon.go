package git

import (
	"os"
	cm "rycus86/githooks/common"
	strs "rycus86/githooks/strings"
)

const (
	// NullRef is the null reference used by git during certain hook execution.
	NullRef = "0000000000000000000000000000000000000000"
)

// IsBareRepo returns `true` if `path` is a bare repository.
func (c *Context) IsBareRepo() bool {
	out, _ := c.Get("rev-parse", "--is-bare-repository")
	return out == "true"
}

// IsGitRepo returns `true` if `path` is a git repository (bare or non-bare).
func (c *Context) IsGitRepo() bool {
	return c.Check("rev-parse") == nil
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
	out, e := Ctx().SanitizeEnv().GetCombined(args...)

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

// UpdateRef executes `git update-ref`.
func (c *Context) UpdateRef(ref string, commitSHA string) error {
	return c.Check("update-ref", ref, commitSHA)
}

// GetRemoteURLAndBranch reports the `remote`s `url` and
// the current `branch` of HEAD.
func (c *Context) GetRemoteURLAndBranch(remote string) (currentURL string, currentBranch string, err error) {
	currentURL = c.GetConfig("remote."+remote+".url", LocalScope)
	currentBranch, err = c.Get("symbolic-ref", "-q", "--short", "HEAD")
	return
}

// PullOrClone either executes a pull in `repoPath` or if not
// existing, clones to this path.
func PullOrClone(repoPath string, url string, branch string, depth int, repoCheck func(*Context) error) (isNewClone bool, err error) {

	gitx := CtxC(repoPath)
	if gitx.IsGitRepo() {
		isNewClone = false

		if repoCheck != nil {
			if err = repoCheck(gitx); err != nil {
				return
			}
		}

		err = gitx.SanitizeEnv().Pull("origin")
	} else {
		isNewClone = true

		if err = os.RemoveAll(repoPath); err != nil {
			err = cm.ErrorF("Could not remove directory '%s'.", repoPath)
			return
		}

		err = Clone(repoPath, url, branch, depth)
	}

	return
}

// RepoCheck is the function which is executed before a fetch.
// Arguments 1 and 2 are `url`, `branch`.
// Return an error to abort the action.
// Return `true` to trigger a complete reclone.
// Available ConfigScope's
type RepoCheck = func(*Context, string, string) (bool, error)

// FetchOrClone either executes a fetch in `repoPath` or if not
// existing, clones to this path.
// The callback `repoCheck` before a fetch can trigger a reclone.
func FetchOrClone(
	repoPath string,
	url string, branch string,
	depth int,
	repoCheck RepoCheck) (isNewClone bool, err error) {

	gitx := CtxC(repoPath).SanitizeEnv()
	if gitx.IsGitRepo() {
		isNewClone = false

		if repoCheck != nil {
			reclone := false
			if reclone, err = repoCheck(gitx, url, branch); err != nil {
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

		err = gitx.SanitizeEnv().Fetch("origin", branch)
	}

	return
}

// GetSHA1HashFile gets the `git hash-object` SHA1 of a `path`.
func GetSHA1HashFile(path string) (string, error) {
	return Ctx().Get("hash-object", path)
}
