package hooks

import (
	"path"
	"path/filepath"
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"
	strs "rycus86/githooks/strings"
)

// RegisterRepos is the format of the register file
// in the install folder.
type RegisterRepos struct {
	GitDirs []string `yaml:"git-dirs"`
}

// RegisterRepo registers the Git directory in the install directory.
func RegisterRepo(absGitDir string, installDir string, filterExisting bool, filterGitDirs bool) error {
	cm.DebugAssertF(filepath.IsAbs(absGitDir),
		"Not an absolute Git dir '%s'", absGitDir)

	var repos RegisterRepos
	err := repos.Load(installDir, filterExisting, filterGitDirs)
	if err != nil {
		return err
	}

	repos.Insert(absGitDir)

	return repos.Store(installDir)
}

// MarkRepoRegistered sets the register flag inside the repo
// to denote the repository as registered.
func MarkRepoRegistered(gitx *git.Context) error {
	return gitx.SetConfig(GitCK_Registered, true, git.LocalScope)
}

// Load gets the registered repos loaded from the register file in the
// install folder.
func (r *RegisterRepos) Load(installDir string, filterExisting bool, filterGitDirs bool) (err error) {

	file := GetRegisterFile(installDir)
	exists, e := cm.IsPathExisting(file)
	err = cm.CombineErrors(err, e)

	if exists {
		err = cm.CombineErrors(err, cm.LoadYAML(file, r))
	}

	if filterExisting {
		r.FilterExisting()
	}

	if filterGitDirs {
		r.FilterGitDirs()
	}

	return err
}

// Store sets the registered repos to the register file in the
// install folder.
func (r *RegisterRepos) Store(installDir string) (err error) {
	file := GetRegisterFile(installDir)

	return cm.StoreYAML(file, &r)
}

// Insert adds a repository Git directory uniquely.
func (r *RegisterRepos) Insert(gitDir string) (inserted bool) {
	c := 0
	r.GitDirs, c = strs.AppendUnique(r.GitDirs, gitDir)
	inserted = c != 0

	return
}

// Remove removes a repository Git directory.
func (r *RegisterRepos) Remove(gitDir string) (removed int) {
	r.GitDirs, removed = strs.Remove(r.GitDirs, gitDir)

	return
}

// FilterExisting filter by existing directories.
func (r *RegisterRepos) FilterExisting() {
	r.GitDirs = strs.Filter(r.GitDirs,
		func(v string) bool {
			exists, _ := cm.IsPathExisting(v)
			return exists // nolint:nlreturn
		})
}

// FilterGitDirs filter by Git directories.
func (r *RegisterRepos) FilterGitDirs() {
	r.GitDirs = strs.Filter(r.GitDirs,
		func(v string) bool {
			return git.CtxC(v).IsGitDir()
		})
}

func GetRegisterFile(installDir string) string {
	return path.Join(installDir, "registered.yaml")
}
