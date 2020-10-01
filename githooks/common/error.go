package common

import (
	"errors"
	"fmt"
	"strings"
)

// GithooksFailure is a normal hook failure
type GithooksFailure struct {
	error string
}

func (e *GithooksFailure) Error() string {
	return e.error
}

// Error makes an error message.
func Error(lines ...string) error {
	return errors.New(strings.Join(lines, "\n"))
}

// ErrorF makes an error message.
func ErrorF(format string, args ...interface{}) error {
	return fmt.Errorf(format, args...)
}

// Panic panics with an `error`.
func Panic(lines ...string) {
	panic(Error(lines...))
}

// PanicF panics with an `error`.
func PanicF(format string, args ...interface{}) {
	panic(ErrorF(format, args...))
}

// AssertPanic Assert a condition is `true`, otherwise panic.
func AssertPanic(condition bool, lines ...string) {
	if !condition {
		Panic(lines...)
	}
}

// AssertPanicF Assert a condition is `true`, otherwise panic.
func AssertPanicF(condition bool, format string, args ...interface{}) {
	if !condition {
		PanicF(format, args...)
	}
}

// PanicIf Assert a condition is `true`, otherwise panic.
func PanicIf(condition bool, lines ...string) {
	if condition {
		Panic(lines...)
	}
}

// PanicIfF Assert a condition is `true`, otherwise panic.
func PanicIfF(condition bool, format string, args ...interface{}) {
	if condition {
		PanicF(format, args...)
	}
}

// AssertNoErrorPanic Assert no error, otherwise panic.
func AssertNoErrorPanic(err error, lines ...string) {
	if err != nil {
		PanicIf(true,
			append(lines, "-> error: ["+err.Error()+"]")...)
	}
}
