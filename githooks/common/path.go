package common

import (
	"os"
	"path"
	"path/filepath"
	strs "rycus86/githooks/strings"
	"strings"
	"time"

	"github.com/mitchellh/go-homedir"
	"github.com/otiai10/copy"
)

const (
	DefaultFileModeDirectory = os.FileMode(0775) // nolint:gomnd
	DefaultFileModeFile      = os.FileMode(0664) // nolint:gomnd

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

// SplitPath splits a path `p` (only forward slashes)
// into each directory name.
func SplitPath(p string) []string {
	return strings.Split(path.Clean(p), "/")
}

// ContainsDotFile checks if path `p` contains `.*` parts (dotfiles)
// in the path.
func ContainsDotFile(p string) bool {
	for _, d := range SplitPath(p) {
		if strings.HasPrefix(d, ".") && len(d) >= 2 && d != "." && d != ".." {
			return true
		}
	}

	return false
}

// FileFilter is the filter for `GetFiles`.
type FileFilter = func(path string, info os.FileInfo) bool

// GetFiles returns the filtered files in directory `root` (non-recursive).
// The nil Filter returns all files.
func GetFiles(root string, filter FileFilter) (files []string, err error) {

	f := func(path string, info os.FileInfo) error {
		if filter == nil || filter(path, info) {
			files = append(files, path)
		}

		return nil
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
type FileFunc = func(path string, info os.FileInfo) error

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
				return nil // nolint:nlreturn
			}

			if info.IsDir() {
				if !rootDirVisited {
					rootDirVisited = true
					return nil // nolint:nlreturn // Skip root dir...
				}
				// Skip all other dirs...
				return filepath.SkipDir
			}

			return filter(filepath.ToSlash(path), info)
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

// ReplaceTildeWith replaces a prefix tilde '~' character in a path
// with the string `repl`.
func ReplaceTildeWith(p string, repl string) string {
	if strings.HasPrefix(p, "~") {
		return path.Join(repl, strings.TrimPrefix(p, "~"))
	}

	return p
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

// MakeExecutable makes a file executable.
func MakeExecutable(path string) (err error) {
	stats, err := os.Stat(path)
	if err != nil {
		return
	}

	var executeMask os.FileMode = 0111
	err = os.Chmod(path, stats.Mode()|executeMask)

	return
}

// TouchFile touches a file `path`.
func TouchFile(filePath string, makeDirs bool) (err error) {
	if IsFile(filePath) {

		currentTime := time.Now().Local()
		err = os.Chtimes(filePath, currentTime, currentTime)

	} else {

		if makeDirs {
			if err = os.MkdirAll(path.Dir(filePath), DefaultFileModeDirectory); err != nil {
				return
			}
		}

		var file *os.File
		if file, err = os.Create(filePath); err != nil {
			return
		}

		err = file.Chmod(DefaultFileModeFile)
	}

	return
}

func CopyFile(src string, dest string) error {
	return copy.Copy(src, dest,
		copy.Options{
			OnSymlink:   func(string) copy.SymlinkAction { return copy.Shallow },
			OnDirExists: func(string, string) copy.DirExistsAction { return copy.Replace }})
}

func CopyDirectory(src string, dest string) error {
	return copy.Copy(src, dest,
		copy.Options{
			OnSymlink:   func(string) copy.SymlinkAction { return copy.Shallow },
			OnDirExists: func(string, string) copy.DirExistsAction { return copy.Replace }})
}

// GetTempPath creates a random non-existing path
// with a postfix `postfix` in directory `dir` (can be empty to use the working dir).
func GetTempPath(dir string, postfix string) (file string) {

	maxLoops := 10
	i := 0

	file = path.Join(dir, strs.RandomString(8)+postfix) // nolint:gomnd
	exists, err := IsPathExisting(file)
	for (err != nil || exists) && i < maxLoops {
		file = path.Join(dir, strs.RandomString(8)+postfix) // nolint:gomnd
		exists, err = IsPathExisting(file)
		i++
	}

	PanicIfF(i == maxLoops, "Could not create random filename in dir '%s'.", dir)

	return
}

// CopyFileWithBackup copies (if `!doMoveInstead`, otherwise moves) the contents of
// the file named `src` to the file named
// by `dst`. If `dst` already exists it will be force moved to `backupDir/dst`.
// Make sure that `backupDir` is on the same device as `dst`
// as otherwise this will fail!
// After this, any failure tries to recover as good as possible
// to not have touched/moved `dst`.
func CopyFileWithBackup(src string, dst string, backupDir string, doMoveInstead bool) (err error) {
	backupFile := ""

	var action func(src string, dest string) error

	if doMoveInstead {
		action = os.Rename
	} else {
		action = CopyFile
	}

	if !IsFile(src) {
		return ErrorF("Source file '%s' does not exist.", src)
	}

	if IsFile(dst) {
		// Force remove any backup file.
		backupFile := GetTempPath(backupDir, "-"+path.Base(dst))

		// Copy destination to the backup file.
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

	// The critical part. Copy (or move) `src` to `dest`.
	err = action(src, dst)

	return
}
