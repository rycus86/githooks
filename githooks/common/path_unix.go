// +build !windows

package common

import "golang.org/x/sys/unix"

// IsExecutable checks if the path is executbale by the current user.
func IsExecutable(path string) bool {
	return unix.Access(path, unix.X_OK) == nil
}
