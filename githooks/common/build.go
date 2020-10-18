// +build !debug

package common

const (
	// IsDebug set to `true` will disable debug asserts and other stuff.
	IsDebug = false

	// DebugLog set to `true` will turn on debug logging.
	DebugLog = false
)

// DebugAssert asserts that a condition is `true`, otherwise panic (disabled in production mode).
func DebugAssert(condition bool, lines ...string) {
}

// DebugAssertF asserts that a condition is `true`, otherwise panic (disabled in production mode).
func DebugAssertF(condition bool, format string, args ...interface{}) {
}

// DebugAssertNoError asserts that a condition is `true`, otherwise panic (disabled in production mode).
func DebugAssertNoError(err error, lines ...string) {
}

// DebugAssertNoErrorF asserts that a condition is `true`, otherwise panic (disabled in production mode).
func DebugAssertNoErrorF(err error, format string, args ...interface{}) {
}
