// +build windows

package main

import (
	"path/filepath"

	"github.com/mitchellh/go-homedir"
)

// GetDefaultTemplateSearchDir returns the search directories for potential template dirs.
func GetDefaultTemplateSearchDir() (first []string, second []string) {

	usr, err := homedir.Dir()
	if err != nil {
		usr = filepath.ToSlash(usr)
		first = append(first, "C:/Program Files/Git/mingw64/share/git-core", usr)
	}

	first = append(first, "C:/Program Files", "C:/Program Files (x86)")
	second = []string{"C:/"}
	return
}
