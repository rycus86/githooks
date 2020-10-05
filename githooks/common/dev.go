package common

const (
	// DebugLog set to `true` will turn on debug logging.
	DebugLog = true
	// IsProduction set to `true` will disable debug asserts and other stuff.
	IsProduction = false
)

// DebugAssert Assert a condition is `true`, otherwise panic (disabled in production mode).
func DebugAssert(condition bool, lines ...string) {
	AssertOrPanic(IsProduction || condition, lines...)
}

// DebugAssertF Assert a condition is `true`, otherwise panic (disabled in production mode).
func DebugAssertF(condition bool, format string, args ...interface{}) {
	AssertOrPanicF(IsProduction || condition, format, args...)
}
