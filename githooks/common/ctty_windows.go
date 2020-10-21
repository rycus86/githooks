// +build windows

package common

import (
	"os"
	"syscall"
)

// GetCtty gets the file descriptor of the controlling terminal.
// Taken from:
// https://github.com/mattn/go-tty/blob/master/tty_windows.go
func GetCtty() (*os.File, error) {
	in, err := syscall.Open("CONIN$", syscall.O_RDWR, 0)
	if err != nil {
		return nil, err
	}

	return os.NewFile(uintptr(in), "/dev/tty"), nil
}
