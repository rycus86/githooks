// +build !windows

package common

import "golang.org/x/sys/unix"

// IsExecutable checks if the path is executable by the current user.
func IsExecutable(path string) bool {
	return unix.Access(path, unix.X_OK) == nil
}

// IsWritable checks if the path is writable by the current user.
func IsWritable(path string) bool {
	return unix.Access(path, unix.W_OK) == nil
}
