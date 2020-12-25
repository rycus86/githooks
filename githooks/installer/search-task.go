package main

import (
	"path"
	cm "rycus86/githooks/common"
)

type PreCommitSearchTask struct {
	Dir     string
	Matches []string
}

func (t *PreCommitSearchTask) Run(exitCh chan bool) (err error) {
	t.Matches, err = cm.Glob(path.Join(t.Dir,
		"**/templates/hooks/pre-commit.sample"))
	return err
}

func (t *PreCommitSearchTask) Clone() cm.ITask {
	c := *t                    // Copy the struct.
	copy(t.Matches, c.Matches) // Create a new slice.
	return &c
}
