package common

import strs "rycus86/githooks/strings"

// AssertWarn Assert a condition is `true`, otherwise log.
func (c *LogContext) AssertWarn(condition bool, lines ...string) {
	if !condition {
		c.LogWarn(lines...)
	}
}

// AssertWarnF Assert a condition is `true`, otherwise log.
func (c *LogContext) AssertWarnF(condition bool, format string, args ...interface{}) {
	if !condition {
		c.LogWarnF(format, args...)
	}
}

// WarnIf Assert a condition is `true`, otherwise log.
func (c *LogContext) WarnIf(condition bool, lines ...string) {
	if condition {
		c.LogWarn(lines...)
	}
}

// WarnIfF Assert a condition is `true`, otherwise log.
func (c *LogContext) WarnIfF(condition bool, format string, args ...interface{}) {
	if condition {
		c.LogWarnF(format, args...)
	}
}

// FatalIf Assert a condition is `true`, otherwise log it.
func (c *LogContext) FatalIf(condition bool, lines ...string) {
	if condition {
		c.LogFatal(lines...)
	}
}

// FatalIfF Assert a condition is `true`, otherwise log it.
func (c *LogContext) FatalIfF(condition bool, format string, args ...interface{}) {
	if condition {
		c.LogFatalF(format, args...)
	}
}

// AssertNoErrorWarn Assert no error, and otherwise log it.
func (c *LogContext) AssertNoErrorWarn(err error, lines ...string) bool {
	if err != nil {
		c.LogWarn(append(lines, strs.SplitLines("-> error: [\n"+err.Error()+"\n]")...)...)
		return false
	}
	return true
}

// AssertNoErrorWarnF Assert no error, and otherwise log it.
func (c *LogContext) AssertNoErrorWarnF(err error, format string, args ...interface{}) bool {
	if err != nil {
		c.LogWarnF(format+"\n-> error: [\n"+err.Error()+"\n]", args...)
		return false
	}
	return true
}

// AssertNoErrorFatal Assert no error, and otherwise log it.
func (c *LogContext) AssertNoErrorFatal(err error, lines ...string) {
	if err != nil {
		c.LogFatal(append(lines, strs.SplitLines("-> error: [\n"+err.Error()+"\n]")...)...)
	}
}

// AssertNoErrorFatalF Assert no error, and otherwise log it.
func (c *LogContext) AssertNoErrorFatalF(err error, format string, args ...interface{}) {
	if err != nil {
		c.LogFatalF(format+"\n-> error: [\n"+err.Error()+"\n]", args...)
	}
}
