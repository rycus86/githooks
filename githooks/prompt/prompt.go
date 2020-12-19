package prompt

import (
	"bufio"
	"io"
	"os"
	"runtime"
	cm "rycus86/githooks/common"
	strs "rycus86/githooks/strings"
	"strings"
)

// IContext defines the interface to show a prompt to the user
type IContext interface {
	ShowPromptOptions(
		text string,
		hintText string,
		shortOptions string,
		longOptions ...string) (string, error)

	ShowPrompt(
		text string,
		defaultAnswer string,
		allowEmpty bool) (string, error)

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

	termOut io.Writer

	termIn        *os.File
	termInScanner *bufio.Scanner

	printAnswer bool

	// Prompt over the tool script if existing.
	execCtx cm.IExecContext
	tool    cm.IExecutable
}

// Close closes the prompt context
func (p *Context) Close() {
	if p.termIn != nil {
		p.termIn.Close()
	}
}

// CreateContext creates a `PrompContext`.
func CreateContext(
	log cm.ILogContext,
	execCtx cm.IExecContext,
	tool cm.IExecutable,
	assertOutputIsTerminal bool,
	useStdIn bool) (IContext, error) {

	var err error

	var output io.Writer
	if !assertOutputIsTerminal || log.IsInfoATerminal() {
		output = log.GetInfoWriter()
	}

	var input *os.File
	printAnswer := false

	if useStdIn {
		input = os.Stdin
		printAnswer = true
	} else {
		input, err = cm.GetCtty()
		// if err != nil we construct below
		// which acts as a fallback
	}

	p := Context{
		log: log,

		promptFmt:     log.GetPromptFormatter(),
		termOut:       output,
		termIn:        input,
		termInScanner: bufio.NewScanner(input),

		printAnswer: printAnswer,

		execCtx: execCtx,
		tool:    tool}

	runtime.SetFinalizer(&p, func(p *Context) { p.Close() })

	return &p, err
}

func getDefaultAnswer(options []string) string {
	for _, r := range options {
		if strings.ToLower(r) != r { // is it an upper case letter?
			return strings.ToLower(r)
		}
	}
	return ""
}

func isAnswerCorrect(answer string, options []string) bool {
	return strs.Any(options, func(o string) bool {
		return strings.ToLower(answer) == strings.ToLower(o)
	})
}
