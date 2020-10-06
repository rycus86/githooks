package hooks

import (
	"path/filepath"
	cm "rycus86/githooks/common"
)

// IsRepoTrusted tells if the repository `repoPath` is trusted.
// On any error `false` is reported together with the error.
func IsRepoTrusted(
	git *cm.GitContext,
	installDir string,
	repoPath string,
	promptUser bool) (bool, error) {

	trustFile := filepath.Join(repoPath, ".githooks", "trust-all")
	var err error
	var isTrusted bool = false

	if cm.PathExists(trustFile) {
		trustFlag := git.GetConfig("githooks.trust.all", cm.LocalScope)

		if trustFlag == "" && promptUser {
			question := "This repository wants you to trust all current and\n" +
				"future hooks without prompting.\n" +
				"Do you want to allow running every current and future hooks?"

			answer, err := ShowPrompt(git, installDir, question, "(yes, No)", "y/N", "Yes", "No")

			if err == nil {
				if answer == "y" || answer == "Y" {
					err = git.SetConfig("githooks.trust.all", true, cm.LocalScope)
					if err == nil {
						isTrusted = true
					}
				} else {
					err = git.SetConfig("githooks.trust.all", false, cm.LocalScope)
				}
			}

		} else if trustFlag == "true" || trustFlag == "y" || trustFlag == "Y" {
			isTrusted = true
		}
	}

	return isTrusted, err
}
