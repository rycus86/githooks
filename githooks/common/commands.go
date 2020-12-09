package common

import (
	"os"
	"os/exec"
	strs "rycus86/githooks/strings"
	"strings"
)

// CmdContext defines the command context to execute commands.
type CmdContext struct {
	BaseCmd string
	Cwd     string
	Env     []string
}

// GetSplit executes a command and splits the output by newlines.
func (c *CmdContext) GetSplit(args ...string) ([]string, error) {
	out, err := c.Get(args...)
	return strs.SplitLines(out), err
}

// Get executes a command and gets the stdout.
func (c *CmdContext) Get(args ...string) (string, error) {
	cmd := exec.Command(c.BaseCmd, args...)
	cmd.Dir = c.Cwd
	cmd.Env = c.Env
	stdout, err := cmd.Output()
	return strings.TrimSpace(string(stdout)), err
}

// GetCombined executes a command and gets the combined stdout and stderr.
func (c *CmdContext) GetCombined(args ...string) (string, error) {
	cmd := exec.Command(c.BaseCmd, args...)
	cmd.Dir = c.Cwd
	cmd.Env = c.Env
	stdout, err := cmd.CombinedOutput()
	return strings.TrimSpace(string(stdout)), err
}

// Check checks if a command executed successfully.
func (c *CmdContext) Check(args ...string) error {
	cmd := exec.Command(c.BaseCmd, args...)
	cmd.Dir = c.Cwd
	cmd.Env = c.Env
	return cmd.Run()
}

// GetExitCode get the exit code of the command.
func (c *CmdContext) GetExitCode(args ...string) (int, error) {
	cmd := exec.Command(c.BaseCmd, args...)
	cmd.Dir = c.Cwd
	cmd.Env = c.Env
	err := cmd.Run()

	if err == nil {
		return 0, nil
	}

	if t, ok := err.(*exec.ExitError); ok {
		return t.ExitCode(), nil

	}
	return -1, err
}

// CheckPiped checks if a command executed successfully.
func (c *CmdContext) CheckPiped(args ...string) error {
	cmd := exec.Command(c.BaseCmd, args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Dir = c.Cwd
	cmd.Env = c.Env
	return cmd.Run()
}
