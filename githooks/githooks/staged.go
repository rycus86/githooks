package hooks

import (
	cm "rycus86/githooks/common"
)

// GetStagedFiles gets all currently staged files.
func GetStagedFiles(git *cm.GitContext) (string, error) {

	changed, err := git.Get("diff", "--cached", "--diff-filter=ACMR", "--name-only")
	if err != nil {
		return "", err
	}
	return changed, nil
}
