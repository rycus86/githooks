package common

import (
	"fmt"
	"io"
	"os"
	"runtime/debug"
	strs "rycus86/githooks/strings"
	"strings"

	"github.com/gookit/color"
	"golang.org/x/term"
)

const (
	githooksSuffix = "" // If you like you can make it: "Githooks: "
	debugSuffix    = "🛠 " + githooksSuffix
	infoSuffix     = "🦎 " + githooksSuffix
	warnSuffix     = "⛑ " + githooksSuffix
	errorSuffix    = "⛔ "
	promptSuffix   = "❓ " + githooksSuffix
	indent         = "   "
)

// ILogContext defines the log interface.
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
	Panic(lines ...string)
	PanicF(format string, args ...interface{})

	// Assert helper functions
	ErrorOrPanicF(isFatal bool, err error, format string, args ...interface{})
	AssertWarn(condition bool, lines ...string)
	AssertWarnF(condition bool, format string, args ...interface{})
	DebugIf(condition bool, lines ...string)
	DebugIfF(condition bool, format string, args ...interface{})
	InfoIf(condition bool, lines ...string)
	InfoIfF(condition bool, format string, args ...interface{})
	WarnIf(condition bool, lines ...string)
	WarnIfF(condition bool, format string, args ...interface{})
	ErrorIf(condition bool, lines ...string)
	ErrorIfF(condition bool, format string, args ...interface{})
	PanicIf(condition bool, lines ...string)
	PanicIfF(condition bool, format string, args ...interface{})
	AssertNoError(err error, lines ...string) bool
	AssertNoErrorF(err error, format string, args ...interface{}) bool
	AssertNoErrorPanic(err error, lines ...string)
	AssertNoErrorPanicF(err error, format string, args ...interface{})

	HasColors() bool
	ColorInfo(string) string
	ColorError(string) string
	ColorPrompt(string) string
	GetIndent() string

	GetInfoFormatter(withColor bool) func(format string, args ...interface{}) string
	GetErrorFormatter(withColor bool) func(format string, args ...interface{}) string
	GetPromptFormatter(withColor bool) func(format string, args ...interface{}) string

	GetInfoWriter() io.Writer
	IsInfoATerminal() bool

	GetErrorWriter() io.Writer
	IsErrorATerminal() bool
}

// Interface for log statistics.
type ILogStats interface {
	ErrorCount() int
	WarningCount() int

	ResetStats()

	EnableStats()
	DisableStats()
}

// LogContext defines the data for a log context.
type LogContext struct {
	debug io.Writer
	info  io.Writer
	warn  io.Writer
	error io.Writer

	infoIsATerminal  bool
	errorIsATerminal bool
	isColorSupported bool

	colorInfo   func(string) string
	colorError  func(string) string
	colorPrompt func(string) string

	doTrackStats bool
	nWarnings    int
	nErrors      int
}

// CreateLogContext creates a log context.
func CreateLogContext(onlyStderr bool) (*LogContext, error) {

	var debug, info, warn, error *os.File

	if onlyStderr {
		info = os.Stderr
		warn = info
		error = info
	} else {
		info = os.Stdout
		warn = os.Stderr
		error = warn
	}

	if DebugLog {
		debug = error
	}

	infoIsATerminal := term.IsTerminal(int(info.Fd()))
	errorIsATerminal := term.IsTerminal(int(error.Fd()))
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
		colorError = colorInfo
		colorPrompt = colorInfo
	}

	log := LogContext{
		debug, info, warn, error,
		infoIsATerminal, errorIsATerminal, hasColors,
		colorInfo, colorError, colorPrompt, true, 0, 0}

	return &log, nil
}

// HasColors returns if the log uses colors.
func (c *LogContext) GetIndent() string {
	return indent
}

// HasColors returns if the log uses colors.
func (c *LogContext) HasColors() bool {
	return c.isColorSupported
}

// ColorInfo returns the colorized string for info-like messages.
func (c *LogContext) ColorInfo(s string) string {
	return c.colorInfo(s)
}

// ColorError returns the colorized string for error-like messages.
func (c *LogContext) ColorError(s string) string {
	return c.colorError(s)
}

// ColorPrompt returns the colorized string for prompt-like messages.
func (c *LogContext) ColorPrompt(s string) string {
	return c.colorPrompt(s)
}

// GetInfoWriter returns the info writer.
func (c *LogContext) GetInfoWriter() io.Writer {
	return c.info
}

// GetErrorWriter returns the error writer.
func (c *LogContext) GetErrorWriter() io.Writer {
	return c.error
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
		fmt.Fprint(c.debug, c.colorInfo(FormatMessage(debugSuffix, indent, lines...)), "\n")
	}
}

// DebugF logs a debug message.
func (c *LogContext) DebugF(format string, args ...interface{}) {
	if DebugLog {
		fmt.Fprint(c.debug, c.colorInfo(FormatMessageF(debugSuffix, indent, format, args...)), "\n")
	}
}

// Info logs a info message.
func (c *LogContext) Info(lines ...string) {
	fmt.Fprint(c.info, c.colorInfo(FormatMessage(infoSuffix, indent, lines...)), "\n")
}

// InfoF logs a info message.
func (c *LogContext) InfoF(format string, args ...interface{}) {
	fmt.Fprint(c.info, c.colorInfo(FormatMessageF(infoSuffix, indent, format, args...)), "\n")
}

// Warn logs a warning message.
func (c *LogContext) Warn(lines ...string) {
	fmt.Fprint(c.warn, c.colorError(FormatMessage(warnSuffix, indent, lines...)), "\n")
	if c.doTrackStats {
		c.nWarnings++
	}
}

// WarnF logs a warning message.
func (c *LogContext) WarnF(format string, args ...interface{}) {
	fmt.Fprint(c.warn, c.colorError(FormatMessageF(warnSuffix, indent, format, args...)), "\n")
	if c.doTrackStats {
		c.nWarnings++
	}
}

// Error logs an error.
func (c *LogContext) Error(lines ...string) {
	fmt.Fprint(c.error, c.colorError(FormatMessage(errorSuffix, indent, lines...)), "\n")
	if c.doTrackStats {
		c.nErrors++
	}
}

// ErrorF logs an error.
func (c *LogContext) ErrorF(format string, args ...interface{}) {
	fmt.Fprint(c.error, c.colorError(FormatMessageF(errorSuffix, indent, format, args...)), "\n")
	if c.doTrackStats {
		c.nErrors++
	}
}

// GetPromptFormatter formats a prompt.
func (c *LogContext) GetPromptFormatter(withColor bool) func(format string, args ...interface{}) string {
	if withColor {
		return func(format string, args ...interface{}) string {
			return c.colorPrompt(FormatMessageF(promptSuffix, indent, format, args...))
		}
	} else {
		return func(format string, args ...interface{}) string {
			return FormatMessageF(promptSuffix, indent, format, args...)
		}
	}
}

// GetErrorFormatter formats an error.
func (c *LogContext) GetErrorFormatter(withColor bool) func(format string, args ...interface{}) string {
	if withColor {
		return func(format string, args ...interface{}) string {
			return c.colorError(FormatMessageF(errorSuffix, indent, format, args...))
		}
	} else {
		return func(format string, args ...interface{}) string {
			return FormatMessageF(errorSuffix, indent, format, args...)
		}
	}
}

// GetInfoFormatter formats an info.
func (c *LogContext) GetInfoFormatter(withColor bool) func(format string, args ...interface{}) string {
	if withColor {
		return func(format string, args ...interface{}) string {
			return c.colorInfo(FormatMessageF(infoSuffix, indent, format, args...))
		}
	} else {
		return func(format string, args ...interface{}) string {
			return FormatMessageF(infoSuffix, indent, format, args...)
		}
	}
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
func (c *LogContext) Panic(lines ...string) {
	m := FormatMessage(errorSuffix, indent, lines...)
	fmt.Fprint(c.error, c.colorError(m), "\n")
	panic(GithooksFailure{m})
}

// FatalF logs an error and calls panic with a GithooksFailure.
func (c *LogContext) PanicF(format string, args ...interface{}) {
	m := FormatMessageF(errorSuffix, indent, format, args...)
	fmt.Fprint(c.error, c.colorError(m), "\n")
	panic(GithooksFailure{m})
}

// Warnings gets the number of logged warnings.
func (c *LogContext) WarningCount() int {
	return c.nWarnings
}

// Errors gets the number of logged errors.
func (c *LogContext) ErrorCount() int {
	return c.nErrors
}

// Reset resets the log statistics.
func (c *LogContext) ResetStats() {
	c.nErrors = 0
	c.nWarnings = 0
}

// DisableStats disables the log statistics.
func (c *LogContext) DisableStats() {
	c.doTrackStats = false
}

// EnableStats enables the log statistics.
func (c *LogContext) EnableStats() {
	c.doTrackStats = false
}

// FormatMessage formats  several lines with a suffix and indent.
func FormatMessage(suffix string, indent string, lines ...string) string {
	return suffix + strings.Join(lines, "\n"+indent)
}

// FormatMessageF formats  several lines with a suffix and indent.
func FormatMessageF(suffix string, indent string, format string, args ...interface{}) string {
	s := suffix + strs.Fmt(format, args...)
	return strings.ReplaceAll(s, "\n", "\n"+indent) // nolint:nlreturn
}

type proxyWriterInfo struct {
	log ILogContext
}

type proxyWriterErr struct {
	log ILogContext
}

func (p *proxyWriterInfo) Write(s []byte) (int, error) {
	return p.log.GetInfoWriter().Write([]byte(p.log.ColorInfo(string(s))))
}

func (p *proxyWriterErr) Write(s []byte) (int, error) {
	return p.log.GetErrorWriter().Write([]byte(p.log.ColorError(string(s))))
}

// ToInfoWriter wrapps the log context info into a `io.Writer`.
func ToInfoWriter(log ILogContext) io.Writer {
	return &proxyWriterInfo{log: log}
}

// ToErrorWriter wrapps the log context error into a `io.Writer`.
func ToErrorWriter(log ILogContext) io.Writer {
	return &proxyWriterErr{log: log}
}
