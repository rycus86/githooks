package main

import (
	"rycus86/githooks/hooks"
	strs "rycus86/githooks/strings"
)

type InstallSet = strs.StringSet

// Settings are the settings for the installer.
type Settings struct {
	Cwd        string // The current working directory.
	InstallDir string // The install directory.
	CloneDir   string // The release clone dir inside the install dir.
	TempDir    string // The temporary directory inside the install dir.

	HookTemplateDir string // The chosen hook template directory.

	// Registered Repos loaded from the install dir.
	// New registered repos will be added here.
	RegisteredGitDirs hooks.RegisterRepos

	// All repositories Git directories where Githooks run wrappers have been installed.
	InstalledGitDirs InstallSet
}
