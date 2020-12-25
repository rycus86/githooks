package main

import (
	"path"
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"
	strs "rycus86/githooks/strings"
	"strings"
)

// PreCommitSearchTask is a task to search for pre-commit files.
type PreCommitSearchTask struct {
	Dir     string
	Matches []string
}

func (t *PreCommitSearchTask) Run(exitCh chan bool) (err error) {
	t.Matches, err = cm.Glob(path.Join(t.Dir,
		"**/templates/hooks/pre-commit.sample"),
		true)
	return err
}

func (t *PreCommitSearchTask) Clone() cm.ITask {
	c := *t                    // Copy the struct.
	copy(t.Matches, c.Matches) // Create a new slice.
	return &c
}

type GitDirsSearchTask struct {
	Dir     string
	Matches []string
}

func (t *GitDirsSearchTask) Run(exitCh chan bool) (err error) {
	t.Matches, err = git.FindGitDirs(t.Dir)

	// Filter '.RepoName' Git repositories.
	t.Matches = strs.Filter(t.Matches, func(s string) bool {
		var repoName string
		if path.Base(s) == ".git" {
			repoName = path.Base(path.Dir(s)) // seems to be a normal repo...
		} else {
			repoName = path.Base(s) // seems to be a bare repo...
		}
		return repoName == "." || !strings.HasPrefix(".", repoName)
	})

	return
}

func (t *GitDirsSearchTask) Clone() cm.ITask {
	c := *t                    // Copy the struct.
	copy(t.Matches, c.Matches) // Create a new slice.
	return &c
}
