package common

import (
	"bytes"
	"io"
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

// PipeSetupFunc is the setup function for the pipes executed
// by the below execution calls.
type PipeSetupFunc func() (io.Reader, io.Writer, io.Writer)

// UseStreams returns a pipe setup function which pipes everything.
func UseStreams(in io.Reader, out io.Writer, err io.Writer) PipeSetupFunc {
	return func() (io.Reader, io.Writer, io.Writer) {
		return in, out, err
	}
}

// UseStdStreams returns a pipe setup function which pipes to the standard in/out/err streams.
func UseStdStreams(pipeStdin bool, pipeStdOut bool, pipeStderr bool) PipeSetupFunc {
	return func() (in io.Reader, out io.Writer, err io.Writer) {
		if pipeStdin {
			in = os.Stdin
		}

		if pipeStdOut {
			out = os.Stdout
		}

		if pipeStderr {
			err = os.Stderr
		}

		return
	}
}

// PipeStdin returns a pipe setup function which pipes stdin.
func UseOnlyStdin(inPipe io.Reader) PipeSetupFunc {
	return func() (io.Reader, io.Writer, io.Writer) {
		return inPipe, nil, nil
	}
}

// GetOutputFromExecutable calls an executable and returns its stdout output.
func GetOutputFromExecutable(
	ctx IExecContext,
	exe IExecutable,
	pipeSetup PipeSetupFunc,
	args ...string) ([]byte, error) {

	args = exe.GetArgs(args...)
	cmd := exec.Command(exe.GetCommand(), args...)
	cmd.Dir = ctx.GetWorkingDir()
	cmd.Env = ctx.GetEnv()

	if pipeSetup != nil {
		cmd.Stdin, _, _ = pipeSetup()
	}

	out, err := cmd.Output()
	if err != nil {
		err = CombineErrors(
			ErrorF("Command failed: '%s %q'.", exe.GetCommand(), args), err)
	}

	return out, err
}

// GetCombinedOutputFromExecutable calls an executable and returns its stdout and stderr output.
func GetCombinedOutputFromExecutable(
	ctx IExecContext,
	exe IExecutable,
	pipeSetup PipeSetupFunc,
	args ...string) ([]byte, error) {

	args = exe.GetArgs(args...)
	cmd := exec.Command(exe.GetCommand(), args...)
	cmd.Dir = ctx.GetWorkingDir()
	cmd.Env = ctx.GetEnv()

	if pipeSetup != nil {
		cmd.Stdin, _, _ = pipeSetup()
	}

	out, err := cmd.CombinedOutput()
	if err != nil {
		err = CombineErrors(
			ErrorF("Command failed: '%s %q'.", exe.GetCommand(), args), err)
	}

	return out, err
}

// GetOutputFromExecutableTrimmed calls an executable and returns its trimmed stdout output.
func GetOutputFromExecutableTrimmed(
	ctx IExecContext,
	exe IExecutable,
	pipeSetup func() (io.Reader, io.Writer, io.Writer),
	args ...string) (string, error) {
	data, err := GetOutputFromExecutable(ctx, exe, pipeSetup, args...)

	return strings.TrimSpace(string(data)), err
}

// GetOutputFromExecutableSep calls an executable and gets stdout and stderr separate.
func GetOutputFromExecutableSep(
	ctx IExecContext,
	exe IExecutable,
	pipeSetup PipeSetupFunc,
	args ...string) ([]byte, []byte, error) {

	args = exe.GetArgs(args...)
	cmd := exec.Command(exe.GetCommand(), args...)
	cmd.Dir = ctx.GetWorkingDir()
	cmd.Env = ctx.GetEnv()

	if pipeSetup != nil {
		cmd.Stdin, _, _ = pipeSetup()
	}

	var b1 bytes.Buffer
	var b2 bytes.Buffer
	cmd.Stdout = &b1
	cmd.Stderr = &b2

	err := cmd.Run()
	if err != nil {
		err = CombineErrors(
			ErrorF("Command failed: '%s %q'.", exe.GetCommand(), args), err)
	}

	return b1.Bytes(), b2.Bytes(), err
}

// RunExecutable calls an executable.
func RunExecutable(
	ctx IExecContext,
	exe IExecutable,
	pipeSetup PipeSetupFunc,
	args ...string) error {

	args = exe.GetArgs(args...)
	cmd := exec.Command(exe.GetCommand(), args...)
	cmd.Dir = ctx.GetWorkingDir()
	cmd.Env = ctx.GetEnv()

	if pipeSetup != nil {
		cmd.Stdin, cmd.Stdout, cmd.Stderr = pipeSetup()
	}

	err := cmd.Run()
	if err != nil {
		err = CombineErrors(
			ErrorF("Command failed: '%s %q'.", exe.GetCommand(), args), err)
	}

	return err
}
