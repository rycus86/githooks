package hooks

import (
	"io/ioutil"
	"os/exec"
	"path"
	"path/filepath"
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"
	strs "rycus86/githooks/strings"
)

// HookDirName denotes the directory name used for repository specific hooks.
var HookDirName = ".githooks"

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
func GetBugReportingInfo(repoPath string) (info string, err error) {
	// Set default if needed
	defer func() {
		if strs.IsEmpty(info) {
			info = strs.Fmt("-> Report this bug to: '%s'", DefaultBugReportingURL)
		}
	}()

	// Check in the repo if possible
	file := path.Join(repoPath, HookDirName, ".bug-report")
	exists, e := cm.IsPathExisting(file)
	if e != nil {
		return info, e
	}

	if exists {
		data, e := ioutil.ReadFile(file)
		if e != nil {
			return info, e
		}
		info = string(data)
	}

	// Check global Git config
	info = git.Ctx().GetConfig("githooks.bugReportInfo", git.GlobalScope)
	return
}

// IsGithooksDisabled checks if Githooks is disabled in
// any config starting from the working dir given by the git context.
func IsGithooksDisabled(gitx *git.Context) bool {
	disabled := gitx.GetConfig("githooks.disable", git.Traverse)
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
func GetInstallDir(gitx *git.Context) string {
	return filepath.ToSlash(gitx.GetConfig("githooks.installDir", git.GlobalScope))
}

// GetToolScript gets the tool script associated with the name `tool`
func GetToolScript(name string, installDir string) (*cm.Executable, error) {

	tool := path.Join(installDir, "tools", name, "run")

	exists, err := cm.IsPathExisting(tool)
	if !exists {
		return nil, nil
	}

	runCmd, err := GetToolRunCmd(tool)
	return &cm.Executable{Path: tool, RunCmd: runCmd}, err
}
