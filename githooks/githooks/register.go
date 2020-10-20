package hooks

import (
	"path"
	"path/filepath"
	cm "rycus86/githooks/common"
	strs "rycus86/githooks/strings"
)

// RegisterRepos is the format of the register file
// in the install folder.
type RegisterRepos struct {
	GitDirs []string
}

// RegisterRepo registers the Git directory in the install directory.
func RegisterRepo(absGitDir string, installDir string, filterExisting bool) error {
	cm.DebugAssertF(filepath.IsAbs(absGitDir),
		"Not an absolute Git dir '%s'", absGitDir)

	repos, err := LoadRegisteredRepos(installDir)
	if err != nil {
		return err
	}

	if filterExisting {
		repos.FilterExisting()
	}

	repos.Insert(absGitDir)
	err = StoreRegisteredRepos(repos, installDir)
	if err != nil {
		return err
	}

	return nil
}

// LoadRegisteredRepos gets the registered repos from a file
func LoadRegisteredRepos(installDir string) (RegisterRepos, error) {
	file := getRegisterFile(installDir)
	var repos RegisterRepos
	exists, err := cm.IsPathExisting(file)

	if exists {
		return repos, cm.LoadJSON(file, &repos)
	}

	return repos, err
}

// StoreRegisteredRepos sets the registered repos to a file
func StoreRegisteredRepos(repos RegisterRepos, installDir string) error {
	file := getRegisterFile(installDir)
	return cm.StoreJSON(file, &repos)
}

// Insert adds a repository Git directory uniquely
func (r *RegisterRepos) Insert(gitDir string) {
	r.GitDirs = strs.AppendUnique(r.GitDirs, gitDir)
}

// Remove removes a repository Git directory
func (r *RegisterRepos) Remove(gitDir string) {
	r.GitDirs = strs.Remove(r.GitDirs, gitDir)
}

// FilterExisting filters non existing Git directories.
func (r *RegisterRepos) FilterExisting() {
	r.GitDirs = strs.Filter(r.GitDirs,
		func(v string) bool {
			exists, _ := cm.IsPathExisting(v)
			return exists
		})
}

func getRegisterFile(installDir string) string {
	return path.Join(installDir, "registered.json")
}
