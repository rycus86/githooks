// +build windows

package common

// GetCtty gets the file descriptor of the controlling terminal.
func GetCtty() (uintptr, error) {
	//@todo implement this
	Panic("not implemented")
	return 0, err
}
