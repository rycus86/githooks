// +build windows
// +build mock

package common

import (
	"os"
)

// GetCtty gets the file descriptor of the controlling terminal.
// Taken from:
// https://github.com/mattn/go-tty/blob/master/tty_windows.go
func GetCtty() (*os.File, error) {
	return nil, ErrorF("No CTTY: Simulating same as on docker.")
}
