// +build !windows

package common

import (
	"os"
)

// GetCtty gets the file descriptor of the controlling terminal.
func GetCtty() (*os.File, error) {
	return os.OpenFile("/dev/tty", os.O_RDONLY, 0)
}
