package common

import (
	"io"
	"log"
	"os"
	"runtime/debug"
	strs "rycus86/githooks/strings"
	"strings"

	"github.com/gookit/color"
	"golang.org/x/term"
)

const (
	githooksSuffix = "Githooks:"
	debugSuffix    = "🛠  " + githooksSuffix + " "
	debugIndent    = "   "
	infoSuffix     = "ℹ  " + githooksSuffix + " "
	infoIndent     = "   "
	warnSuffix     = "⚠  " + githooksSuffix + " "
	warnIndent     = "   "
	errorSuffix    = warnSuffix + " "
	errorIndent    = "   "

	promptSuffix = "❓ " + githooksSuffix + " "
	promptIndent = "   "
)

// ILogContext defines the log interace
type ILogContext interface {
	// Log functions
	Debug(lines ...string)
	DebugF(format string, args ...interface{})
	Info(lines ...string)
	InfoF(format string, args ...interface{})
	Warn(lines ...string)
	WarnF(format string, args ...interface{})
	Error(lines ...string)
	ErrorF(format string, args ...interface{})
	ErrorWithStacktrace(lines ...string)
	ErrorWithStacktraceF(format string, args ...interface{})
	Fatal(lines ...string)
	FatalF(format string, args ...interface{})

	// Assert helper functions
	ErrorOrFatalF(isFatal bool, err error, format string, args ...interface{})
	AssertWarn(condition bool, lines ...string)
	AssertWarnF(condition bool, format string, args ...interface{})
	DebugIf(condition bool, lines ...string)
	DebugIfF(condition bool, format string, args ...interface{})
	InfoIf(condition bool, lines ...string)
	InfoIfF(condition bool, format string, args ...interface{})
	ErrorIf(condition bool, lines ...string)
	ErrorIfF(condition bool, format string, args ...interface{})
	WarnIf(condition bool, lines ...string)
	WarnIfF(condition bool, format string, args ...interface{})
	FatalIf(condition bool, lines ...string)
	FatalIfF(condition bool, format string, args ...interface{})
	AssertNoErrorWarn(err error, lines ...string) bool
	AssertNoErrorWarnF(err error, format string, args ...interface{}) bool
	AssertNoErrorFatal(err error, lines ...string)
	AssertNoErrorFatalF(err error, format string, args ...interface{})

	HasColors() bool
	ColorInfo(string) string
	ColorError(string) string
	ColorPrompt(string) string

	GetPromptFormatter() func(format string, args ...interface{}) string

	GetInfoWriter() io.Writer
	IsInfoATerminal() bool

	GetErrorWriter() io.Writer
	IsErrorATerminal() bool
}

// LogContext defines the data for a log context
type LogContext struct {
	debug *log.Logger
	info  *log.Logger
	warn  *log.Logger
	error *log.Logger

	infoIsATerminal  bool
	errorIsATerminal bool
	isColorSupported bool

	colorInfo   func(string) string
	colorError  func(string) string
	colorPrompt func(string) string
}

// CreateLogContext creates a log context
func CreateLogContext(onlyStderr bool) (ILogContext, error) {

	var debug, info, warn, error *log.Logger

	if onlyStderr {

		// Its good to output everythin to stderr since git
		// might read stdin for certain hooks.
		// Either do redirection (which needs to be bombproof)
		// or just use stderr.
		info = log.New(os.Stderr, "", 0)
		warn = info
		error = info
	} else {
		info = log.New(os.Stdout, "", 0)
		warn = log.New(os.Stderr, "", 0)
		error = warn
	}

	if DebugLog {
		debug = info
	}

	if info == nil || warn == nil || error == nil {
		return nil, Error("Failed to initialized info, warn, error logs")
	}

	infoIsATerminal := term.IsTerminal(int(os.Stderr.Fd()))
	errorIsATerminal := term.IsTerminal(int(os.Stderr.Fd()))
	hasColors := (infoIsATerminal && errorIsATerminal) && color.IsSupportColor()

	var colorInfo func(string) string
	var colorError func(string) string
	var colorPrompt func(string) string

	if hasColors {
		colorInfo = func(s string) string { return color.FgLightBlue.Render(s) }
		colorError = func(s string) string { return color.FgRed.Render(s) }
		colorPrompt = func(s string) string { return color.FgGreen.Render(s) }

	} else {
		colorInfo = func(s string) string { return s }
		colorError = func(s string) string { return s }
		colorPrompt = func(s string) string { return s }
	}

	return &LogContext{debug, info, warn, error,
		infoIsATerminal, errorIsATerminal, hasColors,
		colorInfo, colorError, colorPrompt}, nil
}

// HasColors returns if the log uses colors.
func (c *LogContext) HasColors() bool {
	return c.isColorSupported
}

// ColorInfo returns the colorized string for info-like messages
func (c *LogContext) ColorInfo(s string) string {
	return c.colorInfo(s)
}

// ColorError returns the colorized string for error-like messages
func (c *LogContext) ColorError(s string) string {
	return c.colorError(s)
}

// ColorPrompt returns the colorized string for prompt-like messages
func (c *LogContext) ColorPrompt(s string) string {
	return c.colorPrompt(s)
}

// GetInfoWriter returns the info writer.
func (c *LogContext) GetInfoWriter() io.Writer {
	return c.info.Writer()
}

// GetErrorWriter returns the error writer.
func (c *LogContext) GetErrorWriter() io.Writer {
	return c.error.Writer()
}

// IsInfoATerminal returns `true` if the info log is connected to a terminal.
func (c *LogContext) IsInfoATerminal() bool {
	return c.infoIsATerminal
}

// IsErrorATerminal returns `true` if the error log is connected to a terminal.
func (c *LogContext) IsErrorATerminal() bool {
	return c.errorIsATerminal
}

// Debug logs a debug message.
func (c *LogContext) Debug(lines ...string) {
	if DebugLog {
		c.debug.Printf(c.colorInfo(FormatMessage(debugSuffix, debugIndent, lines...)))
	}
}

// DebugF logs a debug message.
func (c *LogContext) DebugF(format string, args ...interface{}) {
	if DebugLog {
		c.debug.Printf(c.colorInfo(FormatMessageF(debugSuffix, debugIndent, format, args...)))
	}
}

// Info logs a info message.
func (c *LogContext) Info(lines ...string) {
	c.info.Printf(c.colorInfo(FormatMessage(infoSuffix, infoIndent, lines...)))
}

// InfoF logs a info message.
func (c *LogContext) InfoF(format string, args ...interface{}) {
	c.info.Printf(c.colorInfo(FormatMessageF(infoSuffix, infoIndent, format, args...)))
}

// Warn logs a warning message.
func (c *LogContext) Warn(lines ...string) {
	c.warn.Printf(c.colorError(FormatMessage(warnSuffix, warnIndent, lines...)))
}

// WarnF logs a warning message.
func (c *LogContext) WarnF(format string, args ...interface{}) {
	c.warn.Printf(c.colorError(FormatMessageF(warnSuffix, warnIndent, format, args...)))
}

// Error logs an error.
func (c *LogContext) Error(lines ...string) {
	c.error.Printf(c.colorError(FormatMessage(errorSuffix, errorIndent, lines...)))
}

// ErrorF logs an error.
func (c *LogContext) ErrorF(format string, args ...interface{}) {
	c.error.Printf(c.colorError(FormatMessageF(errorSuffix, errorIndent, format, args...)))
}

// GetPromptFormatter colors a prompt.
func (c *LogContext) GetPromptFormatter() func(format string, args ...interface{}) string {

	fmt := func(format string, args ...interface{}) string {
		return c.colorPrompt(FormatMessageF(promptSuffix, promptIndent, format, args...))
	}

	return fmt
}

// ErrorWithStacktrace logs and error with the stack trace.
func (c *LogContext) ErrorWithStacktrace(lines ...string) {
	stackLines := strs.SplitLines(string(debug.Stack()))
	l := append(lines, "", "Stacktrace:", "-----------")
	c.Error(append(l, stackLines...)...)
}

// ErrorWithStacktraceF logs and error with the stack trace.
func (c *LogContext) ErrorWithStacktraceF(format string, args ...interface{}) {
	c.ErrorWithStacktrace(strs.Fmt(format, args...))
}

// Fatal logs an error and calls panic with a GithooksFailure.
func (c *LogContext) Fatal(lines ...string) {
	m := FormatMessage(errorSuffix, errorIndent, lines...)
	c.error.Printf(c.colorError(m))
	panic(GithooksFailure{m})
}

// FatalF logs an error and calls panic with a GithooksFailure.
func (c *LogContext) FatalF(format string, args ...interface{}) {
	m := FormatMessageF(errorSuffix, errorIndent, format, args...)
	c.error.Printf(c.colorError(m))
	panic(GithooksFailure{m})
}

// FormatMessage formats  several lines with a suffix and indent.
func FormatMessage(suffix string, indent string, lines ...string) string {
	return suffix + strings.Join(lines, "\n"+indent)
}

// FormatMessageF formats  several lines with a suffix and indent.
func FormatMessageF(suffix string, indent string, format string, args ...interface{}) string {
	s := suffix + strs.Fmt(format, args...)
	return strings.ReplaceAll(s, "\n", "\n"+indent)
}
