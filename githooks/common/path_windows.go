// +build windows

package common

import (
	"path/filepath"
	"strings"
)

// IsExecutable checks if the path is executbale by the current user.
func IsExecutable(path string) bool {

	// @todo Should be a better check with the WinApi
	// in https://docs.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getbinarytypea
	// and https://godoc.org/golang.org/x/sys/windows
	// first good solution is this one:

	return strings.ToLower(filepath.Ext(path)) == "exe"
}
