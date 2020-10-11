package common

import (
	"os"
	"os/exec"
	"strings"
)

// IExecContext defines the context to execute commands
type IExecContext interface {
	GetWorkingDir() string
}

// GetOutputFromExecutable calls an executable and returns its output.
func GetOutputFromExecutable(
	ctx IExecContext,
	exe *Executable,
	pipeStdIn bool,
	args ...string) (string, error) {

	cmd := exec.Command(exe.GetCommand(), exe.GetArgs(args...)...)

	if pipeStdIn {
		cmd.Stdin = os.Stdin
	}

	cmd.Dir = ctx.GetWorkingDir()
	stdout, err := cmd.CombinedOutput()
	return strings.TrimSpace(string(stdout)), err
}

// RunExecutable calls an executable.
func RunExecutable(
	ctx IExecContext,
	exe *Executable,
	pipeAll bool,
	args ...string) error {

	cmd := exec.Command(exe.GetCommand(), exe.GetArgs(args...)...)

	if pipeAll {
		cmd.Stdin = os.Stdin
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
	}

	cmd.Dir = ctx.GetWorkingDir()
	return cmd.Run()
}
