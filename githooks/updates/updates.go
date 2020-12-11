package updates

import (
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"
	strs "rycus86/githooks/strings"
	"strings"

	"github.com/google/uuid"
	"github.com/hashicorp/go-version"
)

// DefaultURL is the default remote url for release clones.
var DefaultURL = "https://github.com/rycus86/githooks.git"

// DefaultBranch is the default branch for release clones.
var DefaultBranch = "master"

var defaultRemote = "origin"

// ReleaseStatus contains the status of the release clone.
type ReleaseStatus struct {
	RemoteURL  string
	RemoteName string

	IsNewClone bool

	LocalCommitSHA  string
	RemoteCommitSHA string

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

func getFirstNonSkippableCommit(gitx *git.Context, firstSHA string, lastSHA string) (string, error) {

	// Get all commits in between
	commits, e := gitx.GetCommits(firstSHA, lastSHA)
	if e != nil {
		return "", e
	}

	for _, c := range commits {
		trailer, e := gitx.GetCommitLog(c, "%(trailers:key=Update-NoSkip,valueonly")
		if e != nil {
			return "", e
		}

		if strings.Contains(trailer, "true") {
			// Found a commit which is non-skippable.
			return c, nil
		}
	}

	return lastSHA, nil
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

	// Fetch the repository ...
	depth := 1
	isNewClone, err := git.FetchOrClone(cloneDir, url, branch, depth, check)

	if err != nil {
		return
	}

	if isNewClone {
		// Set the values back...
		if err = SetCloneURL(url, branch); err != nil {
			return
		}
	}

	remoteBranch := defaultRemote + "/" + branch
	gitx := git.CtxCSanitized(cloneDir)
	status, err = getStatus(gitx, url, defaultRemote, branch, remoteBranch)
	status.IsNewClone = isNewClone

	// Reset the release branch to determined remote commit sha.
	// We could have found an unskipable commit.
	err = gitx.UpdateRef("refs/remotes/"+remoteBranch, status.RemoteCommitSHA)
	if err != nil {
		return
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

	var updateVersion *version.Version

	if localSHA != remoteSHA {
		// We have an update available,

		// Check first if we
		// need to reset on to the first unskippable commit in the range.
		var unskipCommit string
		unskipCommit, err = getFirstNonSkippableCommit(gitx, localSHA, remoteSHA)
		if err != nil {
			return
		}

		if unskipCommit != remoteSHA {
			remoteSHA = unskipCommit
		}

		// Get the version.
		updateVersion, err = git.GetVersion(gitx, remoteSHA)
		if err != nil {
			return
		}
	}

	status = ReleaseStatus{
		RemoteURL:         url,
		RemoteName:        remoteName,
		LocalCommitSHA:    localSHA,
		RemoteCommitSHA:   remoteSHA,
		IsUpdateAvailable: updateVersion != nil,
		UpdateVersion:     updateVersion,
		Branch:            branch,
		RemoteBranch:      remoteBranch}

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
