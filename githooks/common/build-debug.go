// +build debug

package common

const (
	// IsDebug set to `true` will disable debug asserts and other stuff.
	IsDebug = true

	// DebugLog set to `true` will turn on debug logging.
	DebugLog = true && IsDebug
)

// DebugAssert asserts that a condition is `true`, otherwise panic (disabled in production mode).
func DebugAssert(condition bool, lines ...string) {
	AssertOrPanic(!IsDebug || condition, lines...)
}

// DebugAssertF asserts that a condition is `true`, otherwise panic (disabled in production mode).
func DebugAssertF(condition bool, format string, args ...interface{}) {
	AssertOrPanicF(!IsDebug || condition, format, args...)
}

// DebugAssertNoError asserts that a condition is `true`, otherwise panic (disabled in production mode).
func DebugAssertNoError(err error, lines ...string) {
	if IsDebug {
		AssertNoErrorPanic(err, lines...)
	}
}

// DebugAssertNoErrorF asserts that a condition is `true`, otherwise panic (disabled in production mode).
func DebugAssertNoErrorF(err error, format string, args ...interface{}) {
	if IsDebug {
		AssertNoErrorPanicF(err, format, args...)
	}
}
