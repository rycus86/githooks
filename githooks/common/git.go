package common

import (
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

// GitContext Context to execute git commands
type GitContext struct {
	cwd string
}

// GitC Get git command execution context with current working dir.
func GitC(cwd string) *GitContext {
	return &GitContext{cwd: cwd}
}

// Git Get git command execution context with current working dir.
func Git() *GitContext {
	return &GitContext{}
}

// GetConfig Get Git configuration values
func (c *GitContext) GetConfig(key string, scope ConfigScope) string {
	var out string
	var err error
	if scope != Traverse {
		out, err = c.Get("config", string(scope), key)
	} else {
		out, err = c.Get("config", key)
	}
	if err != nil {
		return out
	}
	return ""
}

// IsConfigSet Is a git config set.
func (c *GitContext) IsConfigSet(key string, scope ConfigScope) bool {
	var err error
	if scope != Traverse {
		err = c.Check("config", string(scope), key)
	} else {
		err = c.Check("config", key)
	}
	return err == nil
}

// GetSplit Execute git command and split the output by newlines.
func (c *GitContext) GetSplit(args ...string) ([]string, error) {
	out, err := c.Get(args...)
	return strs.SplitLines(out), err
}

// Get Execute git command and get the output.
func (c *GitContext) Get(args ...string) (string, error) {
	cmd := exec.Command("git", args...)
	cmd.Dir = c.cwd
	stdout, err := cmd.CombinedOutput()
	return strings.TrimSpace(string(stdout)), err
}

// Check Check if a git command executed successful.
func (c *GitContext) Check(args ...string) error {
	cmd := exec.Command("git", args...)
	cmd.Dir = c.cwd
	return cmd.Run()
}
