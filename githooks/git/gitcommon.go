package git

import (
	"path/filepath"
	cm "rycus86/githooks/common"
	strs "rycus86/githooks/strings"
)

const (
	// NullRef is the null reference used by git during certain hook execution.
	NullRef = "0000000000000000000000000000000000000000"
)

// IsBareRepo returns if `path` is a bare repository.
func IsBareRepo(path string) bool {
	out, _ := CtxC(path).Get("rev-parse", "--is-bare-repository")
	return out == "true"
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
	out, e := Ctx().GetCombined(args...)

	if e != nil {
		return cm.ErrorF("Cloning of '%s'\ninto '%s' failed:\n%s", url, repoPath, out)
	}
	return nil
}

// Pull executes a pull in `repoPath`.
func Pull(repoPath string) error {
	out, e := CtxC(repoPath).GetCombined("pull")
	if e != nil {
		return cm.ErrorF("Pulling of '%s' failed:\n%s", repoPath, out)
	}
	return nil
}

// PullOrClone either executes a pull in `repoPath` or if not
// existing clones to this path.
func PullOrClone(repoPath string, url string, branch string, depth int) (isNewClone bool, err error) {

	if cm.IsDirectory(filepath.Join(repoPath, ".git")) {
		isNewClone = false
		err = Pull(repoPath)
	} else {
		isNewClone = true
		err = Clone(repoPath, url, branch, depth)
	}

	return
}
