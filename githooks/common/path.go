package common

import (
	"os"
	"path/filepath"
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

			if filter == nil || filter(path, info) {
				files = append(files, path)
			}

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

// IsExecOwner tells if the file is executbale by Unix 'owner'.
func IsExecOwner(path string) (bool, error) {
	var info os.FileInfo
	var err error
	if info, err = os.Stat(path); err != nil {
		return false, err
	}
	return info.Mode()&0100 != 0, nil
}

// IsExecGroup tells if the file is executbale by Unix 'group'.
func IsExecGroup(path string) (bool, error) {
	var info os.FileInfo
	var err error
	if info, err = os.Stat(path); err != nil {
		return false, err
	}
	return info.Mode()&0010 != 0, nil
}

// IsExecOther tells if the file is executbale by Unix 'other'.
func IsExecOther(path string) (bool, error) {
	var info os.FileInfo
	var err error
	if info, err = os.Stat(path); err != nil {
		return false, err
	}
	return info.Mode()&0001 != 0, nil
}

// IsExecAny tells if the file executable by either the owner, group or by 'other'.
func IsExecAny(path string) (bool, error) {
	var info os.FileInfo
	var err error
	if info, err = os.Stat(path); err != nil {
		return false, err
	}
	return info.Mode()&0111 != 0, nil
}
