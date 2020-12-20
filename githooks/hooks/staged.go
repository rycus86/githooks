package hooks

import "rycus86/githooks/git"

// GetStagedFiles gets all currently staged files.
func GetStagedFiles(gitx *git.Context) (string, error) {

	changed, err := gitx.Get("diff", "--cached", "--diff-filter=ACMR", "--name-only")
	if err != nil {
		return "", err
	}

	return changed, nil
}
