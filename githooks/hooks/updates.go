package hooks

import (
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"
)

// FetchStatus contains the output for `FetchUpdates`
type FetchStatus struct {
	IsNewClone bool

	LocalCommitSHA  string
	RemoteCommitSHA string

	IsUpdateAvailable bool
	UpdateVersion     string
}

// FetchUpdates fetches updates in the Githooks clone directory.
func FetchUpdates(gitx *git.Context, installDir string) (status FetchStatus, err error) {
	cloneDir := GetReleaseCloneDir(installDir)

	currentURL := gitx.GetConfig("githooks.cloneUrl", git.GlobalScope)
	currentBranch := gitx.GetConfig("githooks.cloneBranch", git.GlobalScope)

	check := func(gitx *git.Context) error {
		u, b, err := gitx.GetRemoteURLAndBranch("origin")

		if err != nil {

			return cm.CombineErrors(cm.ErrorF("Could not check url & branch in repository at '%s'", gitx.GetWorkingDir()), err)

		} else if u != currentURL || b != currentBranch {
			return cm.ErrorF("Cannot fetch updates because 'origin' of clone\n"+
				"'%[1]s'\n"+
				"points to url:\n"+
				"'%[2]s'\n"+
				"on branch '%[3]s'\n"+
				"which is not configured.\n"+
				"See 'git hooks config [set|print] clone-url' and\n"+
				"    'git hooks config [set|print] clone-branch'\n"+
				"Either fix this or delete the clone\n"+
				"'%[1]s'\n"+
				"to trigger a new checkout.", gitx.GetWorkingDir(), u, b)
		}
		return nil
	}

	// Set clone URL and branch
	cloneURL := currentURL
	if cloneURL == "" {
		cloneURL = "https://github.com/rycus86/githooks.git"
	}

	cloneBranch := currentBranch
	if cloneBranch == "" {
		cloneBranch = "master"
	}

	// Fetch the repository ...
	depth := 1
	isNewClone, err := git.FetchOrClone(cloneDir, cloneURL, cloneBranch, depth, check)

	if err != nil {
		return
	}

	gitxClone := git.CtxCSanitized(cloneDir)
	remoteBranch := "origin/" + cloneBranch

	localSHA, e := gitxClone.Get("rev-parse", cloneBranch)
	err = cm.CombineErrors(err, e)

	remoteSHA, e := gitxClone.Get("rev-parse", remoteBranch)
	err = cm.CombineErrors(err, e)

	updateVersion := ""

	if localSHA != remoteSHA {
		// We have an update available
		shortSHA, e := gitxClone.Get("rev-parse", "--short=6", remoteBranch)
		err = cm.CombineErrors(err, e)

		date, e := gitxClone.Get("log", "-1", "--date=format:%y%m.%d%H%M", "--format=%cd", remoteBranch)
		err = cm.CombineErrors(err, e)

		updateVersion = date + "-" + shortSHA
	}

	status = FetchStatus{
		IsNewClone:        isNewClone,
		LocalCommitSHA:    localSHA,
		RemoteCommitSHA:   remoteSHA,
		IsUpdateAvailable: updateVersion != "",
		UpdateVersion:     updateVersion}

	return
}
