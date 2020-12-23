package main

import (
	"rycus86/githooks/hooks"
	"rycus86/githooks/prompt"
)

type InstallMap map[string]bool

// InstallSettings are the settings for the installer.
type InstallSettings struct {
	Cwd        string // The current working directory.
	InstallDir string // The install directory.
	CloneDir   string // The release clone dir inside the install dir.
	TempDir    string // The temporary directory inside the install dir.

	PromptCtx prompt.IContext // The prompt context for UI prompts.

	HookTemplateDir string // The chosen hook template directory.

	// Registered Repos loaded from the install dir.
	RegisteredGitDirs hooks.RegisterRepos

	// All repositories Git directories where Githooks run wrappers have been installed.
	// Bool indicates if it is already registered.
	InstalledGitDirs InstallMap
}

func (m InstallMap) Insert(gitDir string, registered bool) {
	m[gitDir] = registered
}
