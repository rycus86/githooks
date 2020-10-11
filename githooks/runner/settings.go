package main

import (
	cm "rycus86/githooks/common"
	strs "rycus86/githooks/strings"
)

// HookSettings defines hooks related settings for this run.
type HookSettings struct {
	Args               []string       // Rest arguments.
	Git                *cm.GitContext // Git context to execute commands (working dir is this repository)
	RepositoryPath     string         // Repository path.
	RepositoryHooksDir string         // Directory with hooks for this repository.
	GitDir             string         // Git directory.
	InstallDir         string         // Install directory.

	HookPath string // Absolute path of the hook executing this runner.
	HookName string // Name of the hook.
	HookDir  string // Directory of the hook.

	IsTrusted bool // If the repository is a trusted repository.
}

func (s HookSettings) toString() string {
	return strs.Fmt("\n- Args: '%q'\n"+
		"- Repo Path: '%s'\n"+
		"- Repo Hooks: '%s'\n"+
		"- Git Dir: '%s'\n"+
		"- Install Dir: '%s'\n"+
		"- Hook Path: '%s'\n"+
		"- Trusted: '%v'",
		s.Args, s.RepositoryPath, s.RepositoryHooksDir, s.GitDir, s.InstallDir, s.HookPath, s.IsTrusted)
}
