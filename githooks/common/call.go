package common

import (
	"bytes"
	"os"
	"os/exec"
	"strings"
)

// IExecContext defines the context to execute commands
type IExecContext interface {
	GetWorkingDir() string
}

// GetOutputFromExecutable calls an executable and returns its stdout output.
func GetOutputFromExecutable(
	ctx IExecContext,
	exe IExecutable,
	pipeStdIn bool,
	args ...string) ([]byte, error) {

	cmd := exec.Command(exe.GetCommand(), exe.GetArgs(args...)...)

	if pipeStdIn {
		cmd.Stdin = os.Stdin
	}

	cmd.Dir = ctx.GetWorkingDir()
	return cmd.Output()
}

// GetCombinedOutputFromExecutable calls an executable and returns its stdout and stderr output.
func GetCombinedOutputFromExecutable(
	ctx IExecContext,
	exe IExecutable,
	pipeStdIn bool,
	args ...string) ([]byte, error) {

	cmd := exec.Command(exe.GetCommand(), exe.GetArgs(args...)...)

	if pipeStdIn {
		cmd.Stdin = os.Stdin
	}

	cmd.Dir = ctx.GetWorkingDir()
	return cmd.CombinedOutput()
}

// GetOutputFromExecutableTrimmed calls an executable and returns its trimmed stdout output.
func GetOutputFromExecutableTrimmed(ctx IExecContext,
	exe IExecutable,
	pipeStdin bool,
	args ...string) (string, error) {
	data, err := GetOutputFromExecutable(ctx, exe, pipeStdin, args...)
	return strings.TrimSpace(string(data)), err
}

// GetOutputFromExecutableSep calls an executable and gets stdout and stderr seperate.
func GetOutputFromExecutableSep(
	ctx IExecContext,
	exe IExecutable,
	pipeIn bool,
	args ...string) ([]byte, []byte, error) {

	cmd := exec.Command(exe.GetCommand(), exe.GetArgs(args...)...)

	if pipeIn {
		cmd.Stdin = os.Stdin
	}

	var b1 bytes.Buffer
	var b2 bytes.Buffer
	cmd.Stdout = &b1
	cmd.Stderr = &b2

	cmd.Dir = ctx.GetWorkingDir()
	err := cmd.Run()

	return b1.Bytes(), b2.Bytes(), err
}

// RunExecutable calls an executable.
func RunExecutable(
	ctx IExecContext,
	exe IExecutable,
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
