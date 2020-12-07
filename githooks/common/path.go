package common

import (
	"os"
	"path/filepath"
	"strings"

	"github.com/mitchellh/go-homedir"
)

// IsPathError returns `true` if the error is a `os.PathError`
func IsPathError(err error) bool {
	return err != nil && err.(*os.PathError) != nil
}

// IsPathExisting checks if a path exists.
func IsPathExisting(path string) (bool, error) {
	_, err := os.Stat(path)
	if os.IsNotExist(err) || IsPathError(err) {
		return false, nil
	}
	return err == nil, err
}

// FileFilter is the filter for `GetFiles`.
type FileFilter = func(path string, info os.FileInfo) bool

// GetFiles returns the file in directory `root`, non-recursive.
func GetFiles(root string, filter FileFilter) (files []string, err error) {

	rootDirVisited := false

	if filter == nil {
		err = ErrorF("No lambda given")
		return nil, err
	}

	e := filepath.Walk(root,
		func(path string, info os.FileInfo, e error) error {
			if info == nil || err != nil {
				err = CombineErrors(err, e)
				return nil
			}

			if info.IsDir() {
				if !rootDirVisited {
					rootDirVisited = true
					return nil // Skip root dir...
				}
				// Skip all other dirs...
				return filepath.SkipDir
			}

			path = filepath.ToSlash(path)

			if filter(path, info) {
				files = append(files, path)
			}

			return nil
		})

	err = CombineErrors(err, e)

	return
}

// FileFunc is the filter for `GetFiles`.
type FileFunc = func(path string, info os.FileInfo)

// WalkFiles walks all files in directory `root` and calls `filter`.
func WalkFiles(root string, filter FileFunc) (err error) {

	rootDirVisited := false

	if filter == nil {
		return ErrorF("No lambda given")
	}

	e := filepath.Walk(root,
		func(path string, info os.FileInfo, e error) error {
			if info == nil || err != nil {
				err = CombineErrors(err, e)
				return nil
			}

			if info.IsDir() {
				if !rootDirVisited {
					rootDirVisited = true
					return nil // Skip root dir...
				}
				// Skip all other dirs...
				return filepath.SkipDir
			}

			filter(filepath.ToSlash(path), info)

			return nil
		})

	err = CombineErrors(err, e)
	return
}

// IsDirectory checks if a path is a existing directory.
func IsDirectory(path string) bool {
	s, err := os.Stat(path)
	return err == nil && s.IsDir()
}

// IsFile checks if a path is a existing file.
func IsFile(path string) bool {
	s, err := os.Stat(path)
	return err == nil && !s.IsDir()
}

// MakeRelative makes a `path` relative to `base`.
func MakeRelative(base string, path string) (s string, e error) {
	s, e = filepath.Rel(base, path)
	s = filepath.ToSlash(s)
	return
}

// ReplaceTilde replaces a suffix tilde '~' charachter in a path with the home dir.
func ReplaceTilde(path string) (string, error) {
	if strings.HasSuffix(path, "~") {
		usr, err := homedir.Dir()
		if err != nil {
			return path, err
		}
		return filepath.ToSlash(usr), nil
	}
	return path, nil
}
