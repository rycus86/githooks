package common

import (
	"os/exec"
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

// GitConfigGet Get Git configuration values
func GitConfigGet(key string, scope ConfigScope) string {
	var out string
	var err error
	if scope != Traverse {
		out, err = GitOutput("config", string(scope), key)
	} else {
		out, err = GitOutput("config", key)
	}
	if err != nil {
		return out
	}
	return ""
}

// GitOutputSplit Execute git command and split the output by newlines.
func GitOutputSplit(args ...string) ([]string, error) {
	return GitOutputSplitC("", args...)
}

// GitOutputSplitC Execute git command and split the output by newlines.
func GitOutputSplitC(cwd string, args ...string) ([]string, error) {
	out, err := GitOutputC(cwd, args...)
	return SplitLines(out), err
}

// GitOutput Execute git command and get the output.
func GitOutput(args ...string) (string, error) {
	return GitOutputC("", args...)
}

// GitOutputC Execute git command and get the output.
func GitOutputC(cwd string, args ...string) (string, error) {
	cmd := exec.Command("git", args...)
	cmd.Dir = cwd
	stdout, err := cmd.CombinedOutput()
	return string(stdout), err
}

// GitCheck Check if a git command executed successfully.
func GitCheck(args ...string) error {
	return GitCheckC(".", args...)
}

// GitCheckC Check if a git command executed successful.
func GitCheckC(cwd string, args ...string) error {
	cmd := exec.Command("git", args...)
	cmd.Dir = cwd
	return cmd.Run()
}
