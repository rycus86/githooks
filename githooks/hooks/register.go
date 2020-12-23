package hooks

import (
	"io/ioutil"
	"os"
	"path"
	"path/filepath"
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"
	strs "rycus86/githooks/strings"
	"strings"
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

// Load gets the registered repos loaded from the register file in the
// install folder.
func (r *RegisterRepos) Load(installDir string, filterExisting bool, filterGitDirs bool) (err error) {

	file := getRegisterFile(installDir)
	exists, e := cm.IsPathExisting(file)
	err = cm.CombineErrors(err, e)

	if exists {
		err = cm.CombineErrors(err, cm.LoadYAML(file, r))
	}

	// Legacy: Load legacy register file
	// @todo: Remove this as soon as possible
	file = getLegacyRegisterFile(installDir)
	exists, e = cm.IsPathExisting(file)
	err = cm.CombineErrors(err, e)

	if exists {
		data, e := ioutil.ReadFile(file)
		err = cm.CombineErrors(err, e)

		if e == nil {
			for _, gd := range strs.SplitLines(string(data)) {
				gd = strings.TrimSpace(gd)
				if gd != "" {
					r.Insert(gd)
				}
			}
		}
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

	// Legacy: Store legacy register file
	// @todo: Remove this as soon as possible
	var f *os.File
	f, err = os.OpenFile(getLegacyRegisterFile(installDir), os.O_WRONLY|os.O_TRUNC|os.O_CREATE, 0664)
	if err != nil {
		return
	}

	defer f.Close()
	for _, gitdir := range r.GitDirs {
		if _, err = f.Write([]byte(gitdir + "\n")); err != nil {
			return
		}
	}

	file := getRegisterFile(installDir)

	return cm.StoreYAML(file, &r)
}

// Insert adds a repository Git directory uniquely.
func (r *RegisterRepos) Insert(gitDir string) {
	r.GitDirs = strs.AppendUnique(r.GitDirs, gitDir)
}

// Remove removes a repository Git directory.
func (r *RegisterRepos) Remove(gitDir string) {
	r.GitDirs = strs.Remove(r.GitDirs, gitDir)
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

func getRegisterFile(installDir string) string {
	return path.Join(installDir, "registered.yaml")
}

func getLegacyRegisterFile(installDir string) string {
	return path.Join(installDir, "registered")
}
