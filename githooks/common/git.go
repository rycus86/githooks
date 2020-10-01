package common

import (
	"os"
	"os/exec"
	strs "rycus86/githooks/strings"
	"strings"
)

// ConfigScope Defines the scope of a config file, such as local, global or system.
type ConfigScope string

// Available ConfigScope's
const (
	LocalScope  ConfigScope = "--local"
	GlobalScope ConfigScope = "--global"
	System      ConfigScope = "--system"
	Traverse    ConfigScope = ""
)

// GitContext defines the context to execute git commands
type GitContext struct {
	cwd string
}

// GitC Creates a git command execution context with current working dir.
func GitC(cwd string) *GitContext {
	return &GitContext{cwd: cwd}
}

// Git creates a git command execution context with current working dir.
func Git() *GitContext {
	return &GitContext{}
}

// GetConfig gets a Git configuration values.
func (c *GitContext) GetConfig(key string, scope ConfigScope) string {
	var out string
	var err error
	if scope != Traverse {
		out, err = c.Get("config", string(scope), key)
	} else {
		out, err = c.Get("config", key)
	}
	if err == nil {
		return out
	}
	return ""
}

// IsConfigSet tells if a git config is set.
func (c *GitContext) IsConfigSet(key string, scope ConfigScope) bool {
	var err error
	if scope != Traverse {
		err = c.Check("config", string(scope), key)
	} else {
		err = c.Check("config", key)
	}
	return err == nil
}

// GetSplit executes a git command and splits the output by newlines.
func (c *GitContext) GetSplit(args ...string) ([]string, error) {
	out, err := c.Get(args...)
	return strs.SplitLines(out), err
}

// Get executes a git command and gets the output.
func (c *GitContext) Get(args ...string) (string, error) {
	cmd := exec.Command("git", args...)
	cmd.Dir = c.cwd
	stdout, err := cmd.CombinedOutput()
	return strings.TrimSpace(string(stdout)), err
}

// Check checks if a git command executed successfully.
func (c *GitContext) Check(args ...string) error {
	cmd := exec.Command("git", args...)
	cmd.Dir = c.cwd
	return cmd.Run()
}

// CheckPiped checks if a git command executed successfully.
func (c *GitContext) CheckPiped(args ...string) error {
	cmd := exec.Command("git", args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Dir = c.cwd
	return cmd.Run()
}
