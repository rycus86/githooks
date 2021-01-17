package hooks

import (
	"io/ioutil"
	"os"
	"regexp"
	cm "rycus86/githooks/common"

	"github.com/google/shlex"
)

// GetHookRunCmd gets the command string for the hook `hookPath`.
// It returns the command arguments which is `nil` if its an executable.
func GetHookRunCmd(hookPath string) (exec cm.Executable, err error) {
	exec.Path = hookPath

	if cm.IsExecutable(hookPath) {
		return
	}

	runnerFile := hookPath + ".runner"

	if !cm.IsFile(runnerFile) {
		// It does not exists -> get the default runner.
		return GetDefaultRunner(hookPath), nil
	}

	content, e := ioutil.ReadFile(runnerFile)
	if e != nil {
		err = cm.CombineErrors(err, cm.ErrorF("Could not read runner file '%s'", runnerFile))

		return
	}

	args, e := shlex.Split(replaceEnvVariables(string(content)))
	if e != nil {
		err = cm.CombineErrors(err, cm.ErrorF("Could not parse runner file '%s'", runnerFile))

		return
	}

	exec.RunCmd = args

	return
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
