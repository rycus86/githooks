package common

import (
	"io/ioutil"
	"os"
	"os/exec"
	"path"
	strs "rycus86/githooks/strings"
)

// DefaultBugReportingURL is the default url to report errors
var DefaultBugReportingURL = "https://github.com/rycus86/githooks/issues"

// LFSHookNames are the hook names of all Large File System (LFS) hooks.
var LFSHookNames = [4]string{
	"post-checkout",
	"post-commit",
	"post-merge",
	"pre-push"}

// GetBugReportingInfo Get the default bug reporting url.
func GetBugReportingInfo(repoPath string) string {

	// Check in the repo if possible
	file := path.Join(repoPath, ".githooks/.bug-report")
	if PathExists(file) {
		file, err := os.Open(file)
		if err != nil {
			defer file.Close()
			bugReportInfo, err := ioutil.ReadAll(file)
			if err != nil {
				return string(bugReportInfo)
			}
		}
	}
	// Check global Git config
	bugReportInfo := Git().GetConfig("githooks.bugReportInfo", GlobalScope)
	if bugReportInfo != "" {
		return bugReportInfo
	}

	return strs.Fmt("Report this bug to: '%s'", DefaultBugReportingURL)
}

// IsGithooksDisabled checks if Githooks is disabled in
// any config starting from the working dir given by the git context.
func IsGithooksDisabled(git *GitContext) bool {
	disabled := git.GetConfig("githooks.disable", Traverse)
	return disabled == "true" ||
		disabled == "y" || // Legacy
		disabled == "Y" // Legacy
}

// IsLFSAvailable tells if git-lfs is available in the path.
func IsLFSAvailable() bool {
	_, err := exec.LookPath("git-lfs")
	return err != nil
}
