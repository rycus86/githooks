package prompt

import (
	"io"
	"os"
	"runtime"
	cm "rycus86/githooks/common"
	strs "rycus86/githooks/strings"
	"strings"
)

// IContext defines the interface to show a prompt to the user
type IContext interface {
	ShowPrompt(text string,
		hintText string,
		shortOptions string,
		longOptions ...string) (string, error)
	Close()
}

// Formatter is the format function to format a prompt.
type Formatter func(format string, args ...interface{}) string

// Context defines the prompt context based on a `ILogContext`
// or as a fallback using the defined dialog tool if configured.
type Context struct {
	log cm.ILogContext

	// Fallback prompt over the log context if available.
	promptFmt Formatter
	termOut   io.Writer
	termIn    io.Reader

	// Prompt over the tool script if existing.
	execCtx cm.IExecContext
	tool    cm.IExecutable
}

// Close closes the prompt context
func (p *Context) Close() {

	if f, ok := p.termIn.(*os.File); ok {
		f.Close()
	}
}

// CreateContext creates a `PrompContext`.
func CreateContext(
	log cm.ILogContext,
	execCtx cm.IExecContext,
	tool cm.IExecutable) (IContext, error) {

	var terminalWriter io.Writer
	if log.IsInfoATerminal() {
		terminalWriter = log.GetInfoWriter()
	}
	terminalReader, err := cm.GetCtty()

	p := Context{
		log: log,

		promptFmt: log.GetFormatter(),
		termOut:   terminalWriter,
		termIn:    terminalReader,

		execCtx: execCtx,
		tool:    tool}

	if terminalReader != nil {
		runtime.SetFinalizer(&p, func(p *Context) { p.Close() })
	}

	return &p, err
}

func getDefaultAnswer(options []string) string {
	for _, r := range options {
		if strings.ToLower(r) != r {
			return r
		}
	}
	return ""
}

func isAnswerCorrect(answer string, options []string) bool {
	return strs.Any(options, func(o string) bool {
		return strings.ToLower(answer) == strings.ToLower(o)
	})
}
