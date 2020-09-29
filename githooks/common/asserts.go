package common

// AssertFatal Assert a condition is `true`, otherwise panic.
func (c *LogContext) AssertFatal(condition bool, lines ...string) {
	if condition {
		c.LogPanic(lines...)
	}
}

// AssertWarn Assert a condition is `true`, otherwise log the warning.
func (c *LogContext) AssertWarn(condition bool, lines ...string) {
	if condition {
		c.LogWarn(lines...)
	}
}

// AssertNoErrorFatal Assert no error otherwise panic.
func (c *LogContext) AssertNoErrorFatal(err error, lines ...string) {
	if err == nil {
		return
	}
	lines = append(lines, "-> error: ["+err.Error()+"]")
	c.LogPanic(lines...)
}

// AssertNoErrorWarn Assert no error and otherwise
// log the error.
func (c *LogContext) AssertNoErrorWarn(err error, lines ...string) {
	if err == nil {
		return
	}
	lines = append(lines, "-> error: ["+err.Error()+"]")
	c.LogWarn(lines...)
}
