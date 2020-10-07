package common

import (
	"os"
	"os/exec"
	"strings"
)

// ExecContext defines the context to execute commands
type ExecContext interface {
	GetWorkingDir() string
}

// ExecuteScript calls a script `$1`.
// If it is not executable call it as a shell script.
func ExecuteScript(c ExecContext, script string, pipeAll bool, args ...string) (string, error) {

	var cmd *exec.Cmd

	if IsExecutable(script) {
		cmd = exec.Command(script, args...)
	} else {
		// @todo Introduce "runner" concept.
		cmd = exec.Command("sh", append(
			[]string{"sh"},
			args...,
		)...)
	}

	if pipeAll {
		cmd.Stdin = os.Stdin
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
	}

	cmd.Dir = c.GetWorkingDir()
	stdout, err := cmd.CombinedOutput()
	return strings.TrimSpace(string(stdout)), err
}
