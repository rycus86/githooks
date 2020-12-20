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

// PanicIf Assert a condition is `true`, otherwise log it.
func (c *LogContext) PanicIf(condition bool, lines ...string) {
	if condition {
		c.Panic(lines...)
	}
}

// PanicIfF Assert a condition is `true`, otherwise log it.
func (c *LogContext) PanicIfF(condition bool, format string, args ...interface{}) {
	if condition {
		c.PanicF(format, args...)
	}
}

// AssertNoError Assert no error, and otherwise log it.
func (c *LogContext) AssertNoError(err error, lines ...string) bool {
	if err != nil {
		c.Warn(append(lines, strs.SplitLines("-> error: ["+err.Error()+"]")...)...)
		return false //nolint:nlreturn
	}

	return true
}

// AssertNoErrorF Assert no error, and otherwise log it.
func (c *LogContext) AssertNoErrorF(err error, format string, args ...interface{}) bool {
	if err != nil {
		c.WarnF(format+"\n-> error: ["+err.Error()+"]", args...)
		return false //nolint:nlreturn
	}

	return true
}

// AssertNoErrorFatal Assert no error, and otherwise log it.
func (c *LogContext) AssertNoErrorPanic(err error, lines ...string) {
	if err != nil {
		c.Panic(append(lines, strs.SplitLines("-> error: ["+err.Error()+"]")...)...)
	}
}

// AssertNoErrorFatalF Assert no error, and otherwise log it.
func (c *LogContext) AssertNoErrorPanicF(err error, format string, args ...interface{}) {
	if err != nil {
		c.PanicF(format+"\n-> error: ["+err.Error()+"]", args...)
	}
}

// ErrorOrFatalF logs an error or a fatal error and also with a potential occurred error.
func (c *LogContext) ErrorOrPanicF(isFatal bool, err error, format string, args ...interface{}) {
	if isFatal {
		if err != nil {
			c.PanicF(format+"\n-> error: ["+err.Error()+"]", args...)
		} else {
			c.PanicF(format, args...)
		}
	} else {
		if err != nil {
			c.ErrorF(format+"\n-> error: ["+err.Error()+"]", args...)
		} else {
			c.ErrorF(format, args...)
		}
	}
}
