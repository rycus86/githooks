// +build !windows

package common

import (
	"io"
	"os"
)

// GetCtty gets the file descriptor of the controlling terminal.
func GetCtty() (io.Reader, error) {
	return os.OpenFile("/dev/tty", os.O_RDONLY, 0)
}
