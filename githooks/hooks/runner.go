package hooks

import (
	"io/ioutil"
	"os"
	"regexp"
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

		args, e := shlex.Split(replaceEnvVariables(string(content)))
		if e != nil {
			return nil, cm.ErrorF("Could not parse runner file '%s'", runnerFile)
		}
		return args, nil
	}

	// It does not exists -> default is the shell interpreter.
	return defaultRunner, nil
}

var reEnvVariable = regexp.MustCompile(`\$?\$(\{[a-zA-Z]\w*\}|[a-zA-Z]\w*)`)

func replaceEnvVariables(s string) string {
	return reEnvVariable.ReplaceAllStringFunc(s, substituteEnvVariable)
}

func substituteEnvVariable(s string) string {
	r := []rune(s)

	if r[0] == '$' && r[1] == '$' {
		// Escape '$$var' or '$${var}' => '$var' or '${var}'
		return string(r[1:])
	}

	if r[1] == '{' {
		// Case: '${var}'
		return os.Getenv(string(r[2 : len(r)-1]))
	}

	// Case '$var'
	return os.Getenv(string(r[1:]))

}
