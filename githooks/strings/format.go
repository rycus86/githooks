package strs

import (
	"fmt"
	"strings"
)

// NotEmpty returns `true` if the string is not empty.
func IsNotEmpty(s string) bool {
	return s != ""
}

// NotEmpty returns `true` if the string is not empty.
func IsEmpty(s string) bool {
	return s == ""
}

// SplitLines splits a string into an array of strings.
func SplitLines(s string) []string {
	return strings.Split(strings.ReplaceAll(s, "\r\n", "\n"), "\n")
}

// SplitLinesN splits a string into an array of `n` strings + a remainder.
func SplitLinesN(s string, n int) []string {
	return strings.SplitN(strings.Replace(s, "\r\n", "\n", n), "\n", n)
}

// Fmt returns a formatted string.
func Fmt(format string, a ...interface{}) string {
	return fmt.Sprintf(format, a...)
}
