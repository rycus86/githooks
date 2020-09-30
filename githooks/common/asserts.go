package common

// AssertWarn Assert a condition is `true`, otherwise log.
func (c *LogContext) AssertWarn(condition bool, lines ...string) {
	if !condition {
		c.LogWarn(lines...)
	}
}

// AssertFatal Assert a condition is `true`, otherwise log and panic.
func (c *LogContext) AssertFatal(condition bool, lines ...string) {
	if !condition {
		c.LogPanic(lines...)
	}
}

// WarnIf Assert a condition is `true`, otherwise log.
func (c *LogContext) WarnIf(condition bool, lines ...string) {
	if condition {
		c.LogWarn(lines...)
	}
}

// FatalIf Assert a condition is `true`, otherwise log and panic.
func (c *LogContext) FatalIf(condition bool, lines ...string) {
	if condition {
		c.LogPanic(lines...)
	}
}

// WarnIfF Assert a condition is `true`, otherwise log.
func (c *LogContext) WarnIfF(condition bool, format string, args ...interface{}) {
	if condition {
		c.LogWarnF(format, args...)
	}
}

// FatalIfF Assert a condition is `true`, otherwise log and panic.
func (c *LogContext) FatalIfF(condition bool, format string, args ...interface{}) {
	if condition {
		c.LogPanicF(format, args...)
	}
}

// AssertWarnF Assert a condition is `true`, otherwise log.
func (c *LogContext) AssertWarnF(condition bool, format string, args ...interface{}) {
	if !condition {
		c.LogWarnF(format, args...)
	}
}

// AssertFatalF Assert a condition is `true`, otherwise log and panic.
func (c *LogContext) AssertFatalF(condition bool, format string, args ...interface{}) {
	if !condition {
		c.LogPanicF(format, args...)
	}
}

// AssertNoErrorFatal Assert no error, otherwise log and panic.
func (c *LogContext) AssertNoErrorFatal(err error, lines ...string) {
	if err != nil {
		c.FatalIf(true,
			append(lines, "-> error: ["+err.Error()+"]")...)
	}
}

// AssertNoErrorWarn Assert no error, and otherwise log it.
func (c *LogContext) AssertNoErrorWarn(err error, lines ...string) {
	if err != nil {
		c.WarnIf(true,
			append(lines, "-> error: ["+err.Error()+"]")...)
	}
}
