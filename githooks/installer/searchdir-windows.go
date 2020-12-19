// +build windows

package main

import (
	"path"
	"path/filepath"

	"github.com/mitchellh/go-homedir"
)

// GetDefaultTemplateSearchDir returns the search directories for potential template dirs.
func GetDefaultTemplateSearchDir() (first []string, second []string) {

	usr, err := homedir.Dir()
	if err != nil {
		usr = filepath.ToSlash(usr)
		first = append(first, path.Join(usr, "AppData"), usr)
	}

	first = append(first, "C:/Program Files", "C:/Program Files (x86)")
	second = []string{"C:/"}
	return
}
