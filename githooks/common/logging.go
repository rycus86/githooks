package common

import (
	"fmt"
	"io"
	"os"
	"strings"
)

// Fmt Return a formatted string.
func Fmt(format string, a ...interface{}) string {
	return fmt.Sprintf(format, a...)
}

// AssertFatal Assert a condition is `true`, otherwise panic.
func AssertFatal(condition bool, lines ...string) {
	if condition {
		panic(Error(lines...))
	}
}

// AssertWarn Assert a condition is `true`, otherwise log the warning.
func AssertWarn(condition bool, lines ...string) {
	if condition {
		LogWarn(lines...)
	}
}

// AssertNoErrorF Assert no error otherwise panic.
func AssertNoErrorF(err error, lines ...string) {
	if err == nil {
		return
	}
	lines = append(lines, "-> error: ["+err.Error()+"]")
	panic(Error(lines...))
}

// AssertNoErrorW Assert no error and otherwise
// log the error.
func AssertNoErrorW(err error) {
	if err == nil {
		return
	}
	LogError(err)
}

// Error Make an error message.
func Error(lines ...string) error {
	return formatError("⚠ Githooks:: ", "  ", lines...)
}

// LogError Log an error to stderr.
func LogError(err error) {
	os.Stderr.WriteString(err.Error() + "\n")
}

// LogDebug Log a debug message to stdout.
func LogDebug(lines ...string) {
	if DebugLog {
		printMessage(os.Stdout, "🛠  Githooks:: ", "   ", lines...)
	}
}

// LogInfo Log a info message to stdout.
func LogInfo(lines ...string) {
	printMessage(os.Stdout, "ℹ Githooks:: ", "  ", lines...)
}

// LogWarn Log a warning message to stdout.
func LogWarn(lines ...string) {
	printMessage(os.Stdout, "⚠ Githooks:: ", "  ", lines...)
}

func formatError(suffix string, indent string, lines ...string) error {
	return fmt.Errorf(
		"%s%s",
		suffix,
		strings.Join(lines, "\n"+indent))
}

func printMessage(writer io.Writer, suffix string, indent string, lines ...string) {
	fmt.Printf(
		"%s%s\n",
		suffix,
		strings.Join(lines, "\n"+indent))
}
