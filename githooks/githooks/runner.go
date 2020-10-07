package hooks

import (
	"io/ioutil"
	cm "rycus86/githooks/common"

	"github.com/google/shlex"
)

// GetHookRunCmd gets the command string for the hook `hookPath`.
// It returns the command arguments which is `nil` if its an executable.
func GetHookRunCmd(hookPath string) ([]string, error) {
	if cm.IsExecutable(hookPath) {
		return nil, nil
	} else if runnerFile := hookPath + ".runner"; cm.PathExists(runnerFile) {
		content, err := ioutil.ReadFile(runnerFile)
		if err != nil {
			return nil, cm.ErrorF("Could not read runner file '%s'", runnerFile)
		}
		args, err := shlex.Split(string(content))
		if err != nil {
			return nil, cm.ErrorF("Could not parse runner file '%s'", runnerFile)
		}
		return args, nil
	} else {
		// Default is the shell interpreter.
		return []string{"sh"}, nil
	}
}
