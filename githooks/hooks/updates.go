package hooks

import (
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"
	strs "rycus86/githooks/strings"

	"github.com/google/uuid"
)

// FetchStatus contains the output for `FetchUpdates`
type FetchStatus struct {
	IsNewClone bool

	LocalCommitSHA  string
	RemoteCommitSHA string

	IsUpdateAvailable bool
	UpdateVersion     string
}

// GetCloneURL get the clone url and clone branch.
func GetCloneURL() (url string, branch string) {
	gitx := git.Ctx()
	url = gitx.GetConfig("githooks.cloneUrl", git.GlobalScope)
	branch = gitx.GetConfig("githooks.cloneBranch", git.GlobalScope)
	return
}

// SetCloneURL get the clone url and clone branch.
func SetCloneURL(url string, branch string) error {
	gitx := git.Ctx()
	e1 := gitx.SetConfig("githooks.cloneUrl", url, git.GlobalScope)
	e2 := gitx.SetConfig("githooks.cloneBranch", branch, git.GlobalScope)
	return cm.CombineErrors(e1, e2)
}

// FetchUpdates fetches updates in the Githooks clone directory.
func FetchUpdates(installDir string) (status FetchStatus, err error) {
	cm.AssertOrPanic(strs.IsNotEmpty(installDir))

	cloneDir := GetReleaseCloneDir(installDir)
	currentURL, currentBranch := GetCloneURL()

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
	if strs.IsEmpty(cloneURL) {
		cloneURL = "https://github.com/rycus86/githooks.git"
	}

	cloneBranch := currentBranch
	if strs.IsEmpty(cloneBranch) {
		cloneBranch = "master"
	}

	// Fetch the repository ...
	depth := 1
	isNewClone, err := git.FetchOrClone(cloneDir, cloneURL, cloneBranch, depth, check)

	if err != nil {
		return
	}

	if isNewClone {
		// Set the values back...
		if err = SetCloneURL(cloneURL, cloneBranch); err != nil {
			return
		}
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

// MergeUpdates merges updates in the Githooks clone directory.
// Only a fast-forward merge of the remote branch into the local
// branch is performed.
func MergeUpdates(installDir string, dryRun bool) error {
	cm.AssertOrPanic(strs.IsNotEmpty(installDir))
	cloneDir := GetReleaseCloneDir(installDir)

	_, branch := GetCloneURL()
	if strs.IsEmpty(branch) {
		branch = "master"
	}

	remoteBranch := "origin/" + branch

	gitxClone := git.CtxCSanitized(cloneDir)

	if dryRun {
		// Checkout a temporary branch from the current
		// and merge the remote to see if it works.
		branch = "update-" + uuid.New().String()
		if e := gitxClone.Check("branch", branch); e != nil {
			return e
		}
		defer gitxClone.Check("branch", "-D", branch)
	}

	// Fast-forward merge with fetch.
	refSpec := strs.Fmt("%s:%s", remoteBranch, branch)
	if e := gitxClone.Check("fetch", ".", refSpec); e != nil {
		return e
	}

	return nil
}
