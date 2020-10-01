package common

import (
	"log"
	"os"
	"runtime/debug"
	strs "rycus86/githooks/strings"
	"strings"

	"github.com/gookit/color"
)

const (
	githooksSuffix = "Githooks:"
)

// LogContext Data for a log context
type LogContext struct {
	debug *log.Logger
	info  *log.Logger
	warn  *log.Logger
	error *log.Logger

	isColorSupported bool

	renderInfo  func(string) string
	renderError func(string) string
}

// GetLogContext Gets the log context
func GetLogContext() *LogContext {
	var debug *log.Logger
	if DebugLog {
		debug = log.New(os.Stderr, "", 0)
	}

	info := log.New(os.Stdout, "", 0)
	warn := log.New(os.Stderr, "", 0)
	error := log.New(os.Stderr, "", 0)

	hasColors := color.IsSupportColor()

	var renderInfo func(string) string
	var renderError func(string) string
	if hasColors {
		renderInfo = func(s string) string { return color.FgLightBlue.Render(s) }
		renderError = func(s string) string { return color.FgRed.Render(s) }
	} else {
		renderInfo = func(s string) string { return s }
		renderError = func(s string) string { return s }
	}

	return &LogContext{debug, info, warn, error, hasColors, renderInfo, renderError}
}

// LogDebug logs a debug message.
func (c *LogContext) LogDebug(lines ...string) {
	if DebugLog {
		c.debug.Printf(c.renderInfo(formatMessage("🛠  "+githooksSuffix+" ", "   ", lines...)))
	}
}

// LogDebugF logs a debug message.
func (c *LogContext) LogDebugF(format string, args ...interface{}) {
	if DebugLog {
		c.debug.Printf(c.renderInfo(formatMessageF("🛠  "+githooksSuffix+" ", "   ", format, args...)))
	}
}

// LogInfo logs a info message.
func (c *LogContext) LogInfo(lines ...string) {
	c.info.Printf(c.renderInfo(formatMessage("ℹ "+githooksSuffix+" ", "   ", lines...)))
}

// LogInfoF logs a info message.
func (c *LogContext) LogInfoF(format string, args ...interface{}) {
	c.info.Printf(c.renderInfo(formatMessageF("ℹ "+githooksSuffix+" ", "   ", format, args...)))
}

// LogWarn logs a warning message.
func (c *LogContext) LogWarn(lines ...string) {
	c.warn.Printf(c.renderError(formatMessage("⚠ "+githooksSuffix+" ", "  ", lines...)))
}

// LogWarnF logs a warning message.
func (c *LogContext) LogWarnF(format string, args ...interface{}) {
	c.warn.Printf(c.renderError(formatMessageF("⚠ "+githooksSuffix+" ", "  ", format, args...)))
}

// LogError logs an error.
func (c *LogContext) LogError(lines ...string) {
	c.error.Printf(c.renderError(formatMessage("⚠ "+githooksSuffix+" ", "  ", lines...)))
}

// LogErrorF logs an error.
func (c *LogContext) LogErrorF(format string, args ...interface{}) {
	c.error.Printf(c.renderError(formatMessageF("⚠ "+githooksSuffix+" ", "  ", format, args...)))
}

// LogErrorWithStacktrace logs and error with the stack trace.
func (c *LogContext) LogErrorWithStacktrace(lines ...string) {
	stackLines := strs.SplitLines(string(debug.Stack()))
	l := append(lines, "", "Stacktrace:", "-----------")
	c.LogError(append(l, stackLines...)...)
}

// LogErrorWithStacktraceF logs and error with the stack trace.
func (c *LogContext) LogErrorWithStacktraceF(format string, args ...interface{}) {
	c.LogErrorWithStacktrace(strs.Fmt(format, args...))
}

// LogFatal logs an error and calls panic with a GithooksFailure.
func (c *LogContext) LogFatal(lines ...string) {
	m := formatMessage("⚠ "+githooksSuffix+" ", "  ", lines...)
	c.error.Printf(c.renderError(m))
	panic(GithooksFailure{m})
}

// LogFatalF logs an error and calls panic with a GithooksFailure.
func (c *LogContext) LogFatalF(format string, args ...interface{}) {
	m := formatMessageF("⚠ "+githooksSuffix+" ", "  ", format, args...)
	c.error.Printf(c.renderError(m))
	panic(GithooksFailure{m})
}

func formatMessage(suffix string, indent string, lines ...string) string {
	return suffix + strings.Join(lines, "\n"+indent)
}

func formatMessageF(suffix string, indent string, format string, args ...interface{}) string {
	s := suffix + strs.Fmt(format, args...)
	return strings.ReplaceAll(s, "\n", indent+"\n")
}
