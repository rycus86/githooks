package updates

import (
	"regexp"
	"rycus86/githooks/build"
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"
	"rycus86/githooks/hooks"
	"rycus86/githooks/prompt"
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
	UpdateTag         string

	Branch       string
	RemoteBranch string
}

// GetCloneURL get the clone url and clone branch.
func GetCloneURL() (url string, branch string) {
	gitx := git.Ctx()
	url = gitx.GetConfig(hooks.GitCK_CloneUrl, git.GlobalScope)
	branch = gitx.GetConfig(hooks.GitCK_CloneBranch, git.GlobalScope)

	return
}

// SetCloneURL get the clone url and clone branch.
// The `branch` can be empty.
func SetCloneURL(url string, branch string) (err error) {
	cm.DebugAssertF(strs.IsNotEmpty(url), "Wrong input")

	err = git.Ctx().SetConfig(hooks.GitCK_CloneUrl, url, git.GlobalScope)
	if err != nil || strs.IsEmpty(branch) {
		return
	}

	return SetCloneBranch(branch)
}

// Set the Githooks clone branch.
func SetCloneBranch(branch string) error {
	cm.DebugAssertF(strs.IsNotEmpty(branch), "Wrong input")

	return git.Ctx().SetConfig(hooks.GitCK_CloneBranch, branch, git.GlobalScope)
}

// Reset the Githooks clone branch.
func ResetCloneBranch() error {
	return git.Ctx().UnsetConfig(hooks.GitCK_CloneBranch, git.GlobalScope)
}

var unskipTrailerRe = regexp.MustCompile(`Update-NoSkip:\s+true`)

func getNewUpdateCommit(
	gitx *git.Context,
	firstSHA string,
	lastSHA string) (commitF string, tagF string, versionF *version.Version, err error) {

	// Get all commits in (firstSHA, lastSHA]
	commits, err := gitx.GetCommits(firstSHA, lastSHA)
	if err != nil {
		return
	}

	for _, commit := range commits {

		version, tag, e := git.GetVersionAt(gitx, commit)

		if e != nil {
			err = e
			return //nolint: nlreturn
		} else if version == nil || strs.IsEmpty(tag) {
			continue // no version tag on this commit
		}

		// Check if it is an unskippable commit:
		// Get message of the tag (or the commit, if no annotated tag)
		mess, e := gitx.Get("tag", "-l", "--format=%(contents)", tag)
		if e != nil {
			err = e
			return //nolint: nlreturn
		}

		// We have a valid new version on commit 'commit'
		commitF = commit
		tagF = tag
		versionF = version

		if unskipTrailerRe.MatchString(mess) {
			// We stop at this commit since this update cannot be skipped!
			break
		}
	}

	return
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
// Arguments `url` and `branch` can be empty which triggers.
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
		exitCode, e := gitx.GetExitCode("diff-index", "--quiet", git.HEAD)
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

	// If branch was empty, determine it now.
	if strs.IsEmpty(branch) {
		if branch, err = gitx.GetCurrentBranch(); err != nil {
			return
		}
	}

	// Set the url/branch back...
	if err = SetCloneURL(url, branch); err != nil {
		return
	}

	if isNewClone {
		// Reset to latest release tag on the branch
		tag, e := gitx.Get("describe", "--tags", "--abbrev=0", git.HEAD)

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
			return // nolint:nlreturn
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

	updateCommit := ""
	updateTag := ""
	var updateVersion *version.Version

	if localSHA != remoteSHA {
		// We have a potential update available...
		// Get the latest update commit in the range (localSHA, remoteSHA]
		updateCommit, updateTag, updateVersion, err = getNewUpdateCommit(gitx, localSHA, remoteSHA)
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
		UpdateTag:         updateTag,

		Branch:       branch,
		RemoteBranch: remoteBranch}

	return
}

// MergeUpdates merges updates in the Githooks clone directory.
// Only a fast-forward merge of the remote branch into the local
// branch is performed, no remote fetch is performed.
// Returns the commit SHA after the fast-forward.
func MergeUpdates(cloneDir string, dryRun bool) (currentSHA string, err error) {
	if !cm.IsDirectory(cloneDir) {
		err = cm.ErrorF("Clone directory '%s' does not exist.", cloneDir)
		return //nolint: nlreturn
	}

	// Get configured branches...
	_, branch := GetCloneURL()
	remoteBranch := "origin/" + branch

	gitx := git.CtxCSanitized(cloneDir)

	// Safety check that branches are the same.
	currentBranch, err := gitx.Get("rev-parse", "--abbrev-ref", git.HEAD)
	if err != nil {
		return
	}

	if currentBranch != branch {
		err = cm.ErrorF("Current branch of clone directory\n'%s'\n"+
			"does not point to the configured branch '%s'\n"+
			"but instead to '%s'.", cloneDir, branch, currentBranch)
		return //nolint: nlreturn
	}

	if dryRun {
		// Checkout a temporary branch from the current
		// and merge the remote to see if it works.
		branch = "update-" + uuid.New().String()
		if err = gitx.Check("branch", branch); err != nil {
			return
		}
		// Delete the branch on exit.
		defer func() {
			err = cm.CombineErrors(err, gitx.Check("branch", "-D", branch))
		}()
	}

	// Fast-forward merge.
	if err = gitx.Check("merge", "--ff-only", remoteBranch); err != nil {
		return
	}

	// Get the current commit SHA1 after the merge.
	currentSHA, err = gitx.Get("rev-parse", branch)

	return
}

type AcceptUpdateCallback func(status *ReleaseStatus) bool

// RunUpdate runs the procedure of updating Githooks.
func RunUpdate(
	installDir string,
	acceptUpdate AcceptUpdateCallback,
	execX cm.IExecContext,
	pipeSetup cm.PipeSetupFunc) (updateAvailable bool, err error) {

	err = RecordUpdateCheckTimestamp()

	if err != nil {
		err = cm.Error("Could not record update check timestamp.")

		return
	}

	cloneDir := hooks.GetReleaseCloneDir(installDir)
	status, err := FetchUpdates(cloneDir, "", "", true, ErrorOnWrongRemote)
	if err != nil {
		err = cm.CombineErrors(cm.Error("Could not fetch updates."), err)

		return
	}

	updateAvailable = status.IsUpdateAvailable

	if status.IsUpdateAvailable && acceptUpdate(&status) {

		_, err = MergeUpdates(cloneDir, true) // Dry run the merge...
		if err != nil {
			err = cm.CombineErrors(cm.ErrorF(
				"Update cannot run:\n"+
					"Your release clone '%s' cannot be fast-forward merged.\n"+
					"Either fix this or delete the clone to retry.",
				cloneDir), err)

			return
		}

		err = runUpdate(installDir, execX, pipeSetup)
	}

	return
}

func DefaultAcceptUpdateCallback(
	log cm.ILogContext,
	promptCtx prompt.IContext,
	acceptIfNoPrompt bool) AcceptUpdateCallback {

	return func(status *ReleaseStatus) bool {
		log.DebugF("Fetch status: '%v'", status)
		cm.DebugAssert(status.IsUpdateAvailable, "Wrong input.")

		versionText := strs.Fmt(
			"Current version: '%s'\n"+
				"New version: '%s'",
			build.GetBuildVersion(),
			status.UpdateVersion.String())

		if promptCtx != nil {
			question := "There is a new Githooks update available:\n" +
				versionText + "\n" +
				"Would you like to install it now?"

			answer, err := promptCtx.ShowPromptOptions(question,
				"(Yes, no)",
				"Y/n",
				"Yes", "No")
			log.AssertNoErrorF(err, "Could not show prompt.")

			if answer == "y" {
				log.Info("-> Execute update ...")

				return true
			}

		} else {
			log.InfoF("There is a new Githooks update available:\n%s", versionText)

			if acceptIfNoPrompt {
				log.Info("-> Execute update ...")

				return true
			}
		}

		log.Info("-> Update declined")

		return false
	}
}

// runUpdate executes the installer to run the update.
func runUpdate(
	installDir string,
	execC cm.IExecContext,
	pipeSetup cm.PipeSetupFunc) error {

	exec := hooks.GetInstaller(installDir)

	execX := cm.ExecContext{Cwd: execC.GetWorkingDir()}
	execX.Env = git.SanitizeEnv(execC.GetEnv())

	if !cm.IsFile(exec.Path) {
		return cm.ErrorF(
			"Could not execute update, because the installer:\n"+
				"'%s'\n"+
				"is not existing.", exec.Path)
	}

	if pipeSetup == nil {
		output, err := cm.GetCombinedOutputFromExecutable(
			&execX,
			&exec,
			nil,
			"--internal-auto-update")
		// @todo installer: remove "--internal-autoupdate"

		if err != nil {
			return cm.CombineErrors(err, cm.ErrorF("Update output:\n%s", output))
		}

	} else {
		err := cm.RunExecutable(
			&execX,
			&exec,
			pipeSetup,
			"--internal-auto-update")

		if err != nil {
			return cm.CombineErrors(err, cm.Error("Update failed. See output"))
		}
	}

	return nil
}
