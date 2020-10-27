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
		return cm.ErrorF("Pulling '%s' in '%s' failed:\n%s", remote, c.cwd, out)
	}
	return nil
}

// Fetch executes a fetch of a `branch` from the `remote` in `repoPath`.
func (c *Context) Fetch(remote string, branch string) error {
	out, e := c.GetCombined("fetch", remote, branch)
	if e != nil {
		return cm.ErrorF("Fetching of '%s' from '%s'\nin '%s' failed:\n%s", branch, remote, c.cwd, out)
	}
	return nil
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

// FetchOrClone either executes a fetch in `repoPath` or if not
// existing, clones to this path.
func FetchOrClone(repoPath string, url string, branch string, depth int, repoCheck func(*Context) error) (isNewClone bool, err error) {

	gitx := CtxC(repoPath)
	if gitx.IsGitRepo() {
		isNewClone = false

		if repoCheck != nil {
			if err = repoCheck(gitx); err != nil {
				return
			}
		}

		err = gitx.SanitizeEnv().Fetch("origin", branch)

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

// GetSHA1HashFile gets the `git hash-object` SHA1 of a `path`.
func GetSHA1HashFile(path string) (string, error) {
	return Ctx().Get("hash-object", path)
}
