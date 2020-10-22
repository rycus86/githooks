// +build windows

package common

import (
	"path/filepath"
	"syscall"
	"unsafe"
)

var (
	kernel32           = syscall.NewLazyDLL("kernel32.dll")
	procGetBinaryTypeW = kernel32.NewProc("GetBinaryTypeW")
)

const (
	scs32BitBinary = 0
	scs64BitBinary = 6
	scsDOSBinary   = 1
	scsOS216Binary = 5
	scsPIFBinary   = 3
	scsPOSIXBinary = 4
	scsWOWBinary   = 2
)

// IsExecutable tests if a `path` is an executable.
// This wraps: https://docs.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getbinarytypew
func IsExecutable(path string) bool {

	if len([]rune(path)) > syscall.MAX_PATH {
		// If the path is to big we send it directly to the filesystem with a prefix `\\?\`
		// see https://docs.microsoft.com/en-us/windows/win32/fileio/naming-a-file
		p, err := filepath.Abs(path)
		if err != nil {
			return false
		}
		path = `\\?\` + p
	}

	var t uint32
	_, _, e := syscall.Syscall(
		procGetBinaryTypeW.Addr(),
		2,
		uintptr(unsafe.Pointer(syscall.StringToUTF16Ptr(path))),
		uintptr(unsafe.Pointer(&t)),
		0)

	return e == 0 && (t == scs32BitBinary || t == scs64BitBinary)
}
