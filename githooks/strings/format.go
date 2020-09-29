package strs

import (
	"fmt"
	"strings"
)

// SplitLines splits a string into an array of strings.
func SplitLines(s string) []string {
	return strings.Split(strings.Replace(s, "\r\n", "\n", -1), "\n")
}

// Fmt returns a formatted string.
func Fmt(format string, a ...interface{}) string {
	return fmt.Sprintf(format, a...)
}
