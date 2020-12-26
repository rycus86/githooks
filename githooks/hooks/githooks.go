package hooks

import (
	"io/ioutil"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"runtime"
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"
	strs "rycus86/githooks/strings"
	"strings"
)

// HooksDirName denotes the directory name used for repository specific hooks.
const HooksDirName = ".githooks"

const GithooksWebpage = "https://github.com/rycus86/githooks"

// DefaultBugReportingURL is the default url to report errors.
const DefaultBugReportingURL = "https://github.com/rycus86/githooks/issues"

// LFSHookNames are the hook names of all Large File System (LFS) hooks.
var LFSHookNames = [4]string{
	"post-checkout",
	"post-commit",
	"post-merge",
	"pre-push"}

// StagedFilesHookNames are the hook names on which staged files are exported.
var StagedFilesHookNames = [3]string{"pre-commit", "prepare-commit-msg", "commit-msg"}

// EnvVariableStagedFiles is the environment variable which holds the staged files.
const EnvVariableStagedFiles = "STAGED_FILES"

// GetBugReportingInfo gets the default bug reporting url. Argument 'repoPath' can be empty.
func GetBugReportingInfo(repoPath string) (info string, err error) {
	var exists bool

	// Set default if needed
	defer func() {
		if strs.IsEmpty(info) {
			info = strs.Fmt("-> Report this bug to: '%s'", DefaultBugReportingURL)
		}
	}()

	// Check in the repo if possible
	if !strs.IsEmpty(repoPath) {
		file := path.Join(repoPath, HooksDirName, ".bug-report")
		exists, err = cm.IsPathExisting(file)

		if exists {
			data, err := ioutil.ReadFile(file)
			if err == nil {
				info = string(data)
			}
		}
	}

	// Check global Git config
	info = git.Ctx().GetConfig("githooks.bugReportInfo", git.GlobalScope)

	return
}

// HandleCLIErrors generally handles errors for the Githooks executables. Argument `cwd` can be empty.
func HandleCLIErrors(err interface{}, cwd string, log cm.ILogContext) bool {
	if err == nil {
		return false
	}

	var message []string
	withTrace := false

	switch v := err.(type) {
	case cm.GithooksFailure:
		message = append(message, "Fatal error -> Abort.")
	case error:
		info, e := GetBugReportingInfo(cwd)
		v = cm.CombineErrors(v, e)
		message = append(message, v.Error(), info)
		withTrace = true

	default:
		info, e := GetBugReportingInfo(cwd)
		e = cm.CombineErrors(cm.Error("Panic 💩: Unknown error: "), e)
		message = append(message, e.Error(), info)
		withTrace = true
	}

	if log != nil {
		if withTrace {
			log.ErrorWithStacktrace(message...)
		} else {
			log.Error(message...)
		}
	} else {
		os.Stderr.WriteString(strings.Join(message, "\n"))
	}

	return true
}

// IsGithooksDisabled checks if Githooks is disabled in
// any config starting from the working dir given by the git context or
// optional also by the env. variable `GITHOOKS_DISABLE`.
func IsGithooksDisabled(gitx *git.Context, checkEnv bool) bool {

	if checkEnv {
		env := os.Getenv("GITHOOKS_DISABLE")
		if env != "" &&
			env != "0" &&
			env != "false" && env != "off" {
			return true
		}
	}

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
func GetInstallDir() string {
	return filepath.ToSlash(git.Ctx().GetConfig("githooks.installDir", git.GlobalScope))
}

// SetInstallDir sets the global Githooks install directory.
func SetInstallDir(path string) error {
	return git.Ctx().SetConfig("githooks.installDir", path, git.GlobalScope)
}

// GetBinaryDir returns the Githooks binary directory inside the install directory.
func GetBinaryDir(installDir string) string {
	return path.Join(installDir, "bin")
}

// AssertTemporaryDir returns the Githooks temporary directory inside the install directory.
func GetTemporaryDir(installDir string) string {
	cm.DebugAssert(strs.IsNotEmpty(installDir))

	return path.Join(installDir, "tmp")
}

// AssertTemporaryDir returns the Githooks temporary directory inside the install directory.
func AssertTemporaryDir(installDir string) (tempDir string, err error) {
	tempDir = GetTemporaryDir(installDir)
	err = os.MkdirAll(GetTemporaryDir(installDir), cm.DefaultFileModeDirectory)

	return
}

func removeTemporaryDir(installDir string) (err error) {
	cm.DebugAssert(strs.IsNotEmpty(installDir))
	tempDir := GetTemporaryDir(installDir)

	if err = os.RemoveAll(tempDir); err != nil {
		return
	}

	return
}

// CleanTemporaryDir returns the Githooks temporary directory inside the install directory.
func CleanTemporaryDir(installDir string) (string, error) {
	if err := removeTemporaryDir(installDir); err != nil {
		return "", err
	}

	return AssertTemporaryDir(installDir)
}

// GetRunnerExecutable gets the installed Githooks runner executable.
func GetRunnerExecutable(installDir string) (p string) {
	p = path.Join(GetBinaryDir(installDir), "runner")
	if runtime.GOOS == "windows" {
		p += ".exe"
	}

	return
}

// GetInstallerExecutable gets the global Githooks installer executable.
func GetInstallerExecutable(installDir string) (p string) {
	p = path.Join(GetBinaryDir(installDir), "installer")
	if runtime.GOOS == "windows" {
		p += ".exe"
	}

	return
}

// GetCLIExecutable gets the global Githooks CLI executable.
func GetCLIExecutable(installDir string) string {
	return path.Join(GetBinaryDir(installDir), "cli.sh")
}

// SetRunnerExecutableAlias sets the global Githooks runner executable.
func SetRunnerExecutableAlias(path string) error {
	if !cm.IsFile(path) {
		return cm.ErrorF("Runner executable '%s' does not exist.", path)
	}

	return git.Ctx().SetConfig("githooks.runner", path, git.GlobalScope)
}

// SetCLIExecutableAlias sets the global Githooks runner executable.
func SetCLIExecutableAlias(path string) error {
	if !cm.IsFile(path) {
		return cm.ErrorF("CLI executable '%s' does not exist.", path)
	}

	return git.Ctx().SetConfig("alias.hooks", strs.Fmt("!\"%s\"", path), git.GlobalScope)
}

// GetReleaseCloneDir get the release clone directory inside the install dir.
func GetReleaseCloneDir(installDir string) string {
	cm.DebugAssert(strs.IsNotEmpty(installDir), "Empty install dir.")

	return path.Join(installDir, "release")
}

// GetToolScript gets the tool script associated with the name `tool`.
func GetToolScript(installDir string, name string) (cm.IExecutable, error) {

	tool := path.Join(installDir, "tools", name, "run")
	exists, _ := cm.IsPathExisting(tool)
	if !exists {
		return nil, nil
	}

	runCmd, err := GetToolRunCmd(tool)

	return &cm.Executable{Path: tool, RunCmd: runCmd}, err
}

// GetInstaller returns the installer executable in the install directory.
func GetInstaller(installDir string) cm.Executable {
	return cm.Executable{
		Path: path.Join(GetReleaseCloneDir(installDir), "install.sh")}
}
