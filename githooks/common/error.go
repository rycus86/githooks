package common

import (
	"errors"
	"fmt"
	strs "rycus86/githooks/strings"
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

// CombineErrors combines multiple errors into one.
func CombineErrors(errs ...error) error {
	var s string
	anyNotNil := false

	for _, e := range errs {
		if e != nil {
			anyNotNil = true
			if strs.IsNotEmpty(s) {
				s += ",\n"
			}
			s += e.Error()
		}
	}

	if anyNotNil {
		return errors.New(s)
	}

	return nil
}

// Panic panics with an `error`.
func Panic(lines ...string) {
	panic(Error(lines...))
}

// PanicF panics with an `error`.
func PanicF(format string, args ...interface{}) {
	panic(ErrorF(format, args...))
}

// AssertOrPanic Assert a condition is `true`, otherwise panic.
func AssertOrPanic(condition bool, lines ...string) {
	if !condition {
		Panic(lines...)
	}
}

// AssertOrPanicF Assert a condition is `true`, otherwise panic.
func AssertOrPanicF(condition bool, format string, args ...interface{}) {
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
			append(lines, " -> error: ["+err.Error()+"]")...)
	}
}

// AssertNoErrorPanicF Assert no error, otherwise panic.
func AssertNoErrorPanicF(err error, format string, args ...interface{}) {
	if err != nil {
		PanicIfF(true, format+" -> error: ["+err.Error()+"]", args...)
	}
}
