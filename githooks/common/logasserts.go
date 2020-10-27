package common

import strs "rycus86/githooks/strings"

// AssertWarn Assert a condition is `true`, otherwise log.
func (c *LogContext) AssertWarn(condition bool, lines ...string) {
	if !condition {
		c.Warn(lines...)
	}
}

// AssertWarnF Assert a condition is `true`, otherwise log.
func (c *LogContext) AssertWarnF(condition bool, format string, args ...interface{}) {
	if !condition {
		c.WarnF(format, args...)
	}
}

// DebugIf Assert a condition is `true`, otherwise log.
func (c *LogContext) DebugIf(condition bool, lines ...string) {
	if condition {
		c.Debug(lines...)
	}
}

// DebugIfF Assert a condition is `true`, otherwise log.
func (c *LogContext) DebugIfF(condition bool, format string, args ...interface{}) {
	if condition {
		c.DebugF(format, args...)
	}
}

// InfoIf Assert a condition is `true`, otherwise log.
func (c *LogContext) InfoIf(condition bool, lines ...string) {
	if condition {
		c.Info(lines...)
	}
}

// InfoIfF Assert a condition is `true`, otherwise log.
func (c *LogContext) InfoIfF(condition bool, format string, args ...interface{}) {
	if condition {
		c.InfoF(format, args...)
	}
}

// ErrorIf Assert a condition is `true`, otherwise log.
func (c *LogContext) ErrorIf(condition bool, lines ...string) {
	if condition {
		c.Error(lines...)
	}
}

// ErrorIfF Assert a condition is `true`, otherwise log.
func (c *LogContext) ErrorIfF(condition bool, format string, args ...interface{}) {
	if condition {
		c.ErrorF(format, args...)
	}
}

// WarnIf Assert a condition is `true`, otherwise log.
func (c *LogContext) WarnIf(condition bool, lines ...string) {
	if condition {
		c.Warn(lines...)
	}
}

// WarnIfF Assert a condition is `true`, otherwise log.
func (c *LogContext) WarnIfF(condition bool, format string, args ...interface{}) {
	if condition {
		c.WarnF(format, args...)
	}
}

// FatalIf Assert a condition is `true`, otherwise log it.
func (c *LogContext) FatalIf(condition bool, lines ...string) {
	if condition {
		c.Fatal(lines...)
	}
}

// FatalIfF Assert a condition is `true`, otherwise log it.
func (c *LogContext) FatalIfF(condition bool, format string, args ...interface{}) {
	if condition {
		c.FatalF(format, args...)
	}
}

// AssertNoErrorWarn Assert no error, and otherwise log it.
func (c *LogContext) AssertNoErrorWarn(err error, lines ...string) bool {
	if err != nil {
		c.Warn(append(lines, strs.SplitLines("-> error: ["+err.Error()+"]")...)...)
		return false
	}
	return true
}

// AssertNoErrorWarnF Assert no error, and otherwise log it.
func (c *LogContext) AssertNoErrorWarnF(err error, format string, args ...interface{}) bool {
	if err != nil {
		c.WarnF(format+"\n-> error: ["+err.Error()+"]", args...)
		return false
	}
	return true
}

// AssertNoErrorFatal Assert no error, and otherwise log it.
func (c *LogContext) AssertNoErrorFatal(err error, lines ...string) {
	if err != nil {
		c.Fatal(append(lines, strs.SplitLines("-> error: ["+err.Error()+"]")...)...)
	}
}

// AssertNoErrorFatalF Assert no error, and otherwise log it.
func (c *LogContext) AssertNoErrorFatalF(err error, format string, args ...interface{}) {
	if err != nil {
		c.FatalF(format+"\n-> error: ["+err.Error()+"]", args...)
	}
}

// ErrorOrFatalF logs an error or a fatal error and also with a potential occured error.
func (c *LogContext) ErrorOrFatalF(isFatal bool, err error, format string, args ...interface{}) {
	if isFatal {
		if err != nil {
			c.FatalF(format+"\n-> error: ["+err.Error()+"]", args...)
		} else {
			c.FatalF(format, args...)
		}
	} else {
		if err != nil {
			c.ErrorF(format+"\n-> error: ["+err.Error()+"]", args...)
		} else {
			c.ErrorF(format, args...)
		}
	}
}
