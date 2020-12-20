package common

import (
	"bytes"
	"os"
	"os/exec"
	"strings"
)

// IExecContext defines the context interface to execute commands.
type IExecContext interface {
	GetWorkingDir() string
	GetEnv() []string
}

// ExecContext defines a context to execute commands.
type ExecContext struct {
	Cwd string
	Env []string
}

// GetWorkingDir gets the working dir.
func (c *ExecContext) GetWorkingDir() string {
	return c.Cwd
}

// GetEnv gets the environement variables.
func (c *ExecContext) GetEnv() []string {
	return c.Env
}

// GetOutputFromExecutable calls an executable and returns its stdout output.
func GetOutputFromExecutable(
	ctx IExecContext,
	exe IExecutable,
	pipeStdIn bool,
	args ...string) ([]byte, error) {

	args = exe.GetArgs(args...)
	cmd := exec.Command(exe.GetCommand(), args...)
	cmd.Dir = ctx.GetWorkingDir()
	cmd.Env = ctx.GetEnv()

	if pipeStdIn {
		cmd.Stdin = os.Stdin
	}

	out, err := cmd.Output()
	if err != nil {
		err = CombineErrors(
			ErrorF("Command failed: '%s %v'.", exe.GetCommand(), args), err)
	}

	return out, err
}

// GetCombinedOutputFromExecutable calls an executable and returns its stdout and stderr output.
func GetCombinedOutputFromExecutable(
	ctx IExecContext,
	exe IExecutable,
	pipeStdIn bool,
	args ...string) ([]byte, error) {

	args = exe.GetArgs(args...)
	cmd := exec.Command(exe.GetCommand(), args...)
	cmd.Dir = ctx.GetWorkingDir()
	cmd.Env = ctx.GetEnv()

	if pipeStdIn {
		cmd.Stdin = os.Stdin
	}

	out, err := cmd.CombinedOutput()
	if err != nil {
		err = CombineErrors(
			ErrorF("Command failed: '%s %v'.", exe.GetCommand(), args), err)
	}

	return out, err
}

// GetOutputFromExecutableTrimmed calls an executable and returns its trimmed stdout output.
func GetOutputFromExecutableTrimmed(
	ctx IExecContext,
	exe IExecutable,
	pipeStdin bool,
	args ...string) (string, error) {
	data, err := GetOutputFromExecutable(ctx, exe, pipeStdin, args...)

	return strings.TrimSpace(string(data)), err
}

// GetOutputFromExecutableSep calls an executable and gets stdout and stderr separate.
func GetOutputFromExecutableSep(
	ctx IExecContext,
	exe IExecutable,
	pipeIn bool,
	args ...string) ([]byte, []byte, error) {

	args = exe.GetArgs(args...)
	cmd := exec.Command(exe.GetCommand(), args...)
	cmd.Dir = ctx.GetWorkingDir()
	cmd.Env = ctx.GetEnv()

	if pipeIn {
		cmd.Stdin = os.Stdin
	}

	var b1 bytes.Buffer
	var b2 bytes.Buffer
	cmd.Stdout = &b1
	cmd.Stderr = &b2

	err := cmd.Run()
	if err != nil {
		err = CombineErrors(
			ErrorF("Command failed: '%s %v'.", exe.GetCommand(), args), err)
	}

	return b1.Bytes(), b2.Bytes(), err
}

// RunExecutable calls an executable.
func RunExecutable(
	ctx IExecContext,
	exe IExecutable,
	pipeAll bool,
	args ...string) error {

	args = exe.GetArgs(args...)
	cmd := exec.Command(exe.GetCommand(), args...)
	cmd.Dir = ctx.GetWorkingDir()
	cmd.Env = ctx.GetEnv()

	if pipeAll {
		cmd.Stdin = os.Stdin
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
	}

	err := cmd.Run()
	if err != nil {
		err = CombineErrors(
			ErrorF("Command failed: '%s %v'.", exe.GetCommand(), args), err)
	}

	return err
}
