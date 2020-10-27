package hooks

import (
	"io/ioutil"
	cm "rycus86/githooks/common"

	"github.com/google/shlex"
)

// GetToolRunCmd gets the command string for the tool `toolPath`.
// It returns the command arguments which is `nil` if its an executable.
func GetToolRunCmd(toolPath string) ([]string, error) {
	return GetHookRunCmd(toolPath)
}

// GetHookRunCmd gets the command string for the hook `hookPath`.
// It returns the command arguments which is `nil` if its an executable.
func GetHookRunCmd(hookPath string) ([]string, error) {
	if cm.IsExecutable(hookPath) {
		return nil, nil
	}

	runnerFile := hookPath + ".runner"
	exists, err := cm.IsPathExisting(runnerFile)
	if err != nil {
		return nil, cm.ErrorF("Could not check path for runner file '%s'", runnerFile)
	}

	if exists {
		content, e := ioutil.ReadFile(runnerFile)
		if e != nil {
			return nil, cm.ErrorF("Could not read runner file '%s'", runnerFile)
		}
		args, e := shlex.Split(string(content))
		if e != nil {
			return nil, cm.ErrorF("Could not parse runner file '%s'", runnerFile)
		}
		return args, nil
	}

	// It does not exists -> default is the shell interpreter.
	return defaultRunner, nil
}
