package common

const (
	// IsProduction set to `true` will disable debug asserts and other stuff.
	IsProduction = false

	// DebugLog set to `true` will turn on debug logging.
	DebugLog = true && !IsProduction
	// PrintPromptAnswer prints the prompt answer to stdout.
	PrintPromptAnswer = true && DebugLog
)

// DebugAssert asserts that a condition is `true`, otherwise panic (disabled in production mode).
func DebugAssert(condition bool, lines ...string) {
	AssertOrPanic(IsProduction || condition, lines...)
}

// DebugAssertF asserts that a condition is `true`, otherwise panic (disabled in production mode).
func DebugAssertF(condition bool, format string, args ...interface{}) {
	AssertOrPanicF(IsProduction || condition, format, args...)
}

// DebugAssertNoError asserts that a condition is `true`, otherwise panic (disabled in production mode).
func DebugAssertNoError(err error, lines ...string) {
	if IsProduction {
		AssertNoErrorPanic(err, lines...)
	}
}

// DebugAssertNoErrorF asserts that a condition is `true`, otherwise panic (disabled in production mode).
func DebugAssertNoErrorF(err error, format string, args ...interface{}) {
	if IsProduction {
		AssertNoErrorPanicF(err, format, args...)
	}
}
