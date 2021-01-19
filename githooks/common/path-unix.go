// +build !windows

package common

import (
	"os"

	"golang.org/x/sys/unix"
)

// Chmod is a wrapper around the basic Unix `chmod`.
// For windows its different.
func Chmod(filePath string, mode os.FileMode) error {
	return os.Chmod(filePath, mode)
}

// IsExecutable checks if the path is executable by the current user.
func IsExecutable(path string) bool {
	return unix.Access(path, unix.X_OK) == nil
}

// IsWritable checks if the path is writable by the current user.
func IsWritable(path string) bool {
	return unix.Access(path, unix.W_OK) == nil
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
