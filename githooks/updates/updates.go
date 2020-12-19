package updates

import (
	"regexp"
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"
	strs "rycus86/githooks/strings"

	"github.com/google/uuid"
	"github.com/hashicorp/go-version"
)

// ReleaseStatus contains the status of the release clone.
type ReleaseStatus struct {
	RemoteURL  string
	RemoteName string

	IsNewClone bool

	LocalCommitSHA  string
	RemoteCommitSHA string

	UpdateCommitSHA   string
	IsUpdateAvailable bool
	UpdateVersion     *version.Version

	Branch       string
	RemoteBranch string
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

var unskipTrailerRe = regexp.MustCompile(`Update-NoSkip:\s+true`)

func getNewUpdateCommit(gitx *git.Context, firstSHA string, lastSHA string) (string, *version.Version, error) {
	commitFound := ""
	var versionFound *version.Version

	// Get all commits in (firstSHA, lastSHA]
	commits, e := gitx.GetCommits(firstSHA, lastSHA)
	if e != nil {
		return "", nil, e
	}

	for _, c := range commits {

		ver, tag, err := git.GetVersionAt(gitx, c)

		if err != nil {
			return "", nil, err
		} else if ver == nil || strs.IsEmpty(tag) {
			continue // no version tag on this commit
		}

		// We have a valid new
		// version on commit 'c'
		commitFound = c
		versionFound = ver

		// Check if it is an unskippable commit:
		// Get message of the tag (or the commit, if no annotated tag)
		mess, err := gitx.Get("tag", "-l", "--format=%(contents)", tag)
		if err != nil {
			return "", nil, err
		} else if unskipTrailerRe.MatchString(mess) {
			// We stop at this commit since this update cannot be skipped!
			break
		}
	}

	return commitFound, versionFound, nil
}

// RemoteCheckAction is the action type for the remote check.
type RemoteCheckAction string

const (
	// ErrorOnWrongRemote errors out if wrong remote detected.
	ErrorOnWrongRemote RemoteCheckAction = "error"
	// RecloneOnWrongRemote reclones if wrong remote detected.
	RecloneOnWrongRemote RemoteCheckAction = "reclone"
)

// FetchUpdates fetches updates in the Githooks clone directory.
// Arguments `url` and `branch` can be empty which triggers
func FetchUpdates(
	cloneDir string,
	url string,
	branch string,
	checkRemote bool,
	checkRemoteAction RemoteCheckAction) (status ReleaseStatus, err error) {

	cm.AssertOrPanic(strs.IsNotEmpty(cloneDir))

	// Repo check function before fetch is executed.
	check := func(gitx git.Context, url string, branch string) (bool, error) {
		reclone := false

		// Check if clone is dirty, if so error out.
		exitCode, e := gitx.GetExitCode("diff-index", "--quiet", "HEAD")
		if e != nil {
			return false,
				cm.CombineErrors(cm.ErrorF("Could not check dirty state in '%s'",
					gitx.Cwd),
					e)
		}

		if exitCode != 0 {
			return false, cm.ErrorF("Cannot fetch updates because the clone\n"+
				"'%s'\n"+
				"is dirty! Either fix this or delete the clone\n"+
				"to trigger a new checkout.", gitx.Cwd)
		}

		if checkRemote {
			u, b, e := gitx.GetRemoteURLAndBranch(defaultRemote)

			if e != nil {
				return false, cm.CombineErrors(cm.ErrorF(
					"Could not check url & branch in repository at '%s'", gitx.Cwd), e)

			} else if u != url || b != branch {
				if checkRemoteAction != RecloneOnWrongRemote {
					// Default action is error out:
					return false, cm.ErrorF("Cannot fetch updates because '%[6]s' of clone\n"+
						"'%[1]s'\n"+
						"points to url:\n"+
						"'%[2]s'\n"+
						"on branch '%[3]s'\n"+
						"which is not requested\n"+
						" - url: '%[4]s'\n"+
						" - branch: '%[5]s'\n"+
						"See 'git hooks config [set|print] clone-url' and\n"+
						"    'git hooks config [set|print] clone-branch'\n"+
						"Either fix this or delete the clone\n"+
						"'%[1]s'\n"+
						"to trigger a new checkout.", gitx.Cwd, u, b, url, branch, defaultRemote)
				}

				// Do a reclone
				reclone = true
			}
		}

		return reclone, nil
	}

	cURL, cBranch := GetCloneURL()

	// Fallback for url
	if strs.IsEmpty(url) {
		url = cURL
	}
	if strs.IsEmpty(url) {
		url = DefaultURL
	}

	// Fallback for branch.
	if strs.IsEmpty(branch) {
		branch = cBranch
	}
	if strs.IsEmpty(branch) {
		branch = DefaultBranch
	}

	// Fetch or clone he repository:
	depth := -1 // Fetch the whole branch because we need tags on the branch
	isNewClone, err := git.FetchOrClone(cloneDir, url, branch, depth, check)
	if err != nil {
		return
	}

	gitx := git.CtxCSanitized(cloneDir)
	resetRemoteTo := ""

	if isNewClone {
		// Set the url/branch back...
		if err = SetCloneURL(url, branch); err != nil {
			return
		}

		// Reset to latest release tag on the branch
		tag, e := gitx.Get("describe", "--tags", "--abbrev=0", "HEAD")

		if e != nil {
			err = cm.CombineErrors(
				cm.ErrorF("No version tag could be found on branch '%s'",
					branch), e)
			return
		}

		e = gitx.Check("reset", "--hard", tag)
		if e != nil {
			err = cm.CombineErrors(
				cm.ErrorF("Could not reset branch '%s' to tag '%s'",
					branch, tag), e)
			return
		}

		// Get the commit it points to and reset the remote to it
		resetRemoteTo, e = gitx.Get("rev-list", "-n", "1", tag)
		if e != nil {
			err = e
			return
		}
	}

	remoteBranch := defaultRemote + "/" + branch
	status, err = getStatus(gitx, url, defaultRemote, branch, remoteBranch)

	status.IsNewClone = isNewClone
	if status.IsUpdateAvailable {
		resetRemoteTo = status.UpdateCommitSHA
	}

	if strs.IsNotEmpty(resetRemoteTo) {
		// Reset the release branch to determined update commit sha.
		err = gitx.Check("update-ref", "refs/remotes/"+remoteBranch, resetRemoteTo)
		if err != nil {
			return
		}

		status.RemoteCommitSHA = resetRemoteTo
	}

	return
}

// GetStatus returns the status of the release clone.
func GetStatus(cloneDir string, checkRemote bool) (status ReleaseStatus, err error) {

	gitx := git.CtxCSanitized(cloneDir)

	var url, branch string
	url, branch, err = gitx.GetRemoteURLAndBranch(defaultRemote)
	if err != nil {
		return
	}

	if checkRemote {
		configURL, configBranch := GetCloneURL()

		if url != configURL || branch != configBranch {
			// Default action is error out:
			err = cm.ErrorF("Cannot get status because '%s' of clone\n"+
				"'%[1]s'\n"+
				"points to url:\n"+
				"'%[2]s'\n"+
				"on branch '%[3]s'\n"+
				"which is not requested\n"+
				" - url: '%[4]s'\n"+
				" - branch: '%[5]s'\n"+
				"See 'git hooks config [set|print] clone-url' and\n"+
				"    'git hooks config [set|print] clone-branch'\n"+
				"Either fix this or delete the clone\n"+
				"'%[1]s'\n"+
				"to trigger a new checkout.", gitx.Cwd, url, branch, configURL, configBranch)

			return
		}
	}

	remoteBranch := defaultRemote + "/" + branch

	return getStatus(gitx, url, defaultRemote, branch, remoteBranch)
}

func getStatus(
	gitx *git.Context,
	url string,
	remoteName string,
	branch string,
	remoteBranch string) (status ReleaseStatus, err error) {

	var localSHA, remoteSHA string

	localSHA, err = gitx.Get("rev-parse", branch)
	if err != nil {
		return
	}

	remoteSHA, err = gitx.Get("rev-parse", remoteBranch)
	if err != nil {
		return
	}

	var updateCommit = ""
	var updateVersion *version.Version

	if localSHA != remoteSHA {
		// We have a potential update available...
		// Get the latest update commit in the range (localSHA, remoteSHA]
		updateCommit, updateVersion, err = getNewUpdateCommit(gitx, localSHA, remoteSHA)
		if err != nil {
			return
		}
	}

	status = ReleaseStatus{
		RemoteURL:       url,
		RemoteName:      remoteName,
		LocalCommitSHA:  localSHA,
		RemoteCommitSHA: remoteSHA,

		IsUpdateAvailable: updateVersion != nil,
		UpdateVersion:     updateVersion,
		UpdateCommitSHA:   updateCommit,

		Branch:       branch,
		RemoteBranch: remoteBranch}

	return
}

// MergeUpdates merges updates in the Githooks clone directory.
// Only a fast-forward merge of the remote branch into the local
// branch is performed.
func MergeUpdates(cloneDir string, dryRun bool) error {
	cm.AssertOrPanic(strs.IsNotEmpty(cloneDir))

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
