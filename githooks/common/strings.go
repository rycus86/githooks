package common

import "strings"

// SplitLines Split a string into an array of strings
func SplitLines(s string) []string {
	return strings.Split(strings.Replace(s, "\r\n", "\n", -1), "\n")
}
