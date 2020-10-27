package git

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

// Context defines the context to execute it commands
type Context struct {
	cwd string
	env []string
}

// GetWorkingDir gets the current working dir of the context
// to implement `IExecContext`
func (c *Context) GetWorkingDir() string {
	return c.cwd
}

// CtxC creates a git command execution context with current working dir.
func CtxC(cwd string) *Context {
	return &Context{cwd: cwd}
}

// CtxCSanitized creates a git command execution context with current working dir and sanitized environement.
func CtxCSanitized(cwd string) *Context {
	return (&Context{cwd: cwd}).SanitizeEnv()
}

// Ctx creates a git command execution context with current working dir.
func Ctx() *Context {
	return &Context{}
}

// SanitizeEnv sanitizes the execution environment.
func (c *Context) SanitizeEnv() *Context {
	c.env = sanitizeEnv(os.Environ())
	return c
}

// GetConfig gets a Git configuration values.
func (c *Context) GetConfig(key string, scope ConfigScope) string {
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

// getConfigWithArgs gets a Git configuration values.
func (c *Context) getConfigWithArgs(key string, scope ConfigScope, args ...string) string {
	var out string
	var err error
	if scope != Traverse {
		out, err = c.Get(append(append([]string{"config"}, args...), string(scope), key)...)
	} else {
		out, err = c.Get(append(append([]string{"config"}, args...), key)...)
	}
	if err == nil {
		return out
	}
	return ""
}

// GetConfigAll gets a all Git configuration values.
func (c *Context) GetConfigAll(key string, scope ConfigScope, args ...string) []string {
	return strs.SplitLines(c.getConfigWithArgs(key, scope, "--get-all"))
}

// GetConfigAllU gets a all Git configuration values unsplitted.
func (c *Context) GetConfigAllU(key string, scope ConfigScope, args ...string) string {
	return c.getConfigWithArgs(key, scope, "--get-all")
}

// SetConfig sets a Git configuration values.
func (c *Context) SetConfig(key string, value interface{}, scope ConfigScope) error {
	v := strs.Fmt("%v", value)

	if scope != Traverse {
		return c.Check("config", string(scope), key, v)
	}
	return c.Check("config", key, v)
}

// IsConfigSet tells if a git config is set.
func (c *Context) IsConfigSet(key string, scope ConfigScope) bool {
	var err error
	if scope != Traverse {
		err = c.Check("config", string(scope), key)
	} else {
		err = c.Check("config", key)
	}
	return err == nil
}

// GetSplit executes a git command and splits the output by newlines.
func (c *Context) GetSplit(args ...string) ([]string, error) {
	out, err := c.Get(args...)
	return strs.SplitLines(out), err
}

// Get executes a git command and gets the stdout.
func (c *Context) Get(args ...string) (string, error) {
	cmd := exec.Command("git", args...)
	cmd.Dir = c.cwd
	cmd.Env = c.env
	stdout, err := cmd.Output()
	return strings.TrimSpace(string(stdout)), err
}

// GetCombined executes a git command and gets the combined stdout and stderr.
func (c *Context) GetCombined(args ...string) (string, error) {
	cmd := exec.Command("git", args...)
	cmd.Dir = c.cwd
	cmd.Env = c.env
	stdout, err := cmd.CombinedOutput()
	return strings.TrimSpace(string(stdout)), err
}

// Check checks if a git command executed successfully.
func (c *Context) Check(args ...string) error {
	cmd := exec.Command("git", args...)
	cmd.Dir = c.cwd
	cmd.Env = c.env
	return cmd.Run()
}

// CheckPiped checks if a git command executed successfully.
func (c *Context) CheckPiped(args ...string) error {
	cmd := exec.Command("git", args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Dir = c.cwd
	cmd.Env = c.env
	return cmd.Run()
}

func sanitizeEnv(env []string) []string {
	return strs.Filter(env, func(s string) bool {
		return !strings.Contains(s, "GIT_DIR") && !strings.Contains(s, "GIT_WORK_TREE")
	})
}
