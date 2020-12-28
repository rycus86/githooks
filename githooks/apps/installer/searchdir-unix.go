// +build !windows

package main

// GetDefaultTemplateSearchDir returns the search directories for potential template dirs.
func GetDefaultTemplateSearchDir() ([]string, []string) {
	return []string{"/usr"}, []string{"/"}
}
