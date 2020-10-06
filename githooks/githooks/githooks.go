package hooks

import (
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	cm "rycus86/githooks/common"
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

// StagedFilesHookNames are the hook names on which staged files are exported
var StagedFilesHookNames = [3]string{"pre-commit", "prepare-commit-msg", "commit-msg"}

// EnvVariableStagedFiles is the environment variable which holds the staged files.
const EnvVariableStagedFiles = "STAGED_FILES"

// GetBugReportingInfo Get the default bug reporting url.
func GetBugReportingInfo(repoPath string) string {

	// Check in the repo if possible
	file := filepath.Join(repoPath, ".githooks", ".bug-report")
	if cm.PathExists(file) {
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
	bugReportInfo := cm.Git().GetConfig("githooks.bugReportInfo", cm.GlobalScope)
	if bugReportInfo != "" {
		return bugReportInfo
	}

	return strs.Fmt("-> Report this bug to: '%s'", DefaultBugReportingURL)
}

// IsGithooksDisabled checks if Githooks is disabled in
// any config starting from the working dir given by the git context.
func IsGithooksDisabled(git *cm.GitContext) bool {
	disabled := git.GetConfig("githooks.disable", cm.Traverse)
	return disabled == "true" ||
		disabled == "y" || // Legacy
		disabled == "Y" // Legacy
}

// IsLFSAvailable tells if git-lfs is available in the path.
func IsLFSAvailable() bool {
	_, err := exec.LookPath("git-lfs")
	return err == nil
}

// GetInstallDir returns the Githooks install directory.
func GetInstallDir(git *cm.GitContext) string {
	return git.GetConfig("githooks.installDir", cm.GlobalScope)
}

// GetToolScript gets the tool script associated with the name `tool`
func GetToolScript(name string, installDir string) string {
	tool := filepath.Join(installDir, "tools", name, "run")
	if cm.PathExists(tool) {
		return tool
	}
	return ""
}
