package common

import (
	"io"
	"os"
	"path"
	"path/filepath"
	strs "rycus86/githooks/strings"
	"strings"

	"github.com/mitchellh/go-homedir"
)

// IsPathError returns `true` if the error is a `os.PathError`.
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

// GetFiles returns the filtered files in directory `root` (non-recursive).
func GetFiles(root string, filter FileFilter) (files []string, err error) {
	f := func(path string, info os.FileInfo) {
		if filter != nil && filter(path, info) {
			files = append(files, path)
		}
	}

	err = WalkFiles(root, f)

	return
}

// GetAllFiles returns all the files in directory `root` (non-recursive).
func GetAllFiles(root string) (files []string, err error) {
	return GetFiles(root,
		func(path string, info os.FileInfo) bool { return true })
}

// FileFunc is the filter for `GetFiles`.
type FileFunc = func(path string, info os.FileInfo)

// WalkFiles walks all files in directory `root` (non-recursive) and calls `filter`.
func WalkFiles(root string, filter FileFunc) (err error) {

	rootDirVisited := false

	if filter == nil {
		return ErrorF("No lambda given")
	}

	e := filepath.Walk(root,
		func(path string, info os.FileInfo, e error) error {
			if info == nil || err != nil {
				err = CombineErrors(err, e)
				return nil //nolint:nlreturn
			}

			if info.IsDir() {
				if !rootDirVisited {
					rootDirVisited = true
					return nil //nolint:nlreturn // Skip root dir...
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

// ReplaceTilde replaces a prefix tilde '~' character in a path
// with the home dir.
func ReplaceTilde(p string) (string, error) {
	if strings.HasPrefix(p, "~") {
		usr, err := homedir.Dir()
		if err != nil {
			return p, err
		}

		return path.Join(filepath.ToSlash(usr), strings.TrimPrefix(p, "~")), nil
	}

	return p, nil
}

// MakeExecutbale makes a file executbale.
func MakeExecutbale(path string) (err error) {
	stats, err := os.Stat(path)
	if err != nil {
		return
	}

	var executeMask os.FileMode = 0111
	err = os.Chmod(path, stats.Mode()|executeMask)

	return
}

// CopyFile copies the contents of the file named src to the file named
// by dst. The file will be created if it does not already exist. If the
// destination file exists, all it's contents will be replaced by the contents
// of the source file.
func CopyFile(src string, dst string) (err error) {
	in, err := os.Open(src)
	if err != nil {
		return
	}
	defer in.Close()

	out, err := os.Create(dst)
	if err != nil {
		return
	}

	defer func() {
		cerr := out.Close()
		err = CombineErrors(err, cerr)
	}()

	if _, err = io.Copy(out, in); err != nil {
		return
	}

	err = out.Sync()

	return
}

// MoveFileWithBackup moves the contents of the file named `src` to the file named
// by `dst`. If `dst` already exists it will be force moved to `dst + .old`.
// After this, any failure tries to recover as good as possible
// to not have touched/moved `dst`.
func MoveFileWithBackup(src string, dst string) (err error) {
	backUpPrefix := ".old"
	backupFile := ""

	if !IsFile(src) {
		return ErrorF("Source file '%s' does not exist.", src)
	}

	if IsFile(dst) {
		// Force remove any backup file.
		backupFile := dst + backUpPrefix
		if IsFile(backupFile) {
			if err = os.Remove(backupFile); err != nil {
				return
			}
		}
		// Move destination to the backup file.
		if err = os.Rename(dst, backupFile); err != nil {
			return
		}
	}

	// Rollback operation if any error happens
	defer func() {
		if err != nil && strs.IsNotEmpty(backupFile) {
			if e := os.Rename(backupFile, dst); e != nil {
				err = CombineErrors(err,
					ErrorF("Could not rollback by copying '%s' to '%s'.",
						backupFile, dst))
			}
		}
	}()

	// The critical part. Move `src` to `dest`.
	err = os.Rename(src, dst)

	return
}
