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

type AnswerValidator func(string) error

// IContext defines the interface to show a prompt to the user.
type IContext interface {
	ShowPromptOptions(
		text string,
		hintText string,
		shortOptions string,
		longOptions ...string) (string, error)

	ShowPrompt(
		text string,
		defaultAnswer string,
		validator AnswerValidator) (string, error)

	ShowPromptMulti(
		text string,
		validator AnswerValidator) ([]string, error)

	Close()
}

// Formatter is the format function to format a prompt.
type Formatter func(format string, args ...interface{}) string

// Context defines the prompt context based on a `ILogContext`
// or as a fallback using the defined dialog tool if configured.
type Context struct {
	log cm.ILogContext

	promptFmt Formatter
	errorFmt  Formatter

	termOut io.Writer

	termIn        *os.File
	termInScanner *bufio.Scanner

	printAnswer     bool
	maxTries        uint
	panicIfMaxTries bool

	// Prompt over the tool script if existing.
	execCtx cm.IExecContext
	tool    cm.IExecutable
}

// Close closes the prompt context.
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
	maxTries := uint(3) //nolint: gomnd

	if useStdIn {
		input = os.Stdin
		printAnswer = true
		maxTries = uint(1) //nolint: gomnd
	} else {
		input, err = cm.GetCtty()
		// if err != nil we construct below
		// which acts as a fallback
	}

	p := Context{
		log: log,

		errorFmt:      log.GetErrorFormatter(),
		promptFmt:     log.GetPromptFormatter(),
		termOut:       output,
		termIn:        input,
		termInScanner: bufio.NewScanner(input),

		maxTries:        maxTries,
		panicIfMaxTries: true,
		printAnswer:     printAnswer,

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

func CreateValidatorAnswerOptions(options []string) AnswerValidator {

	return func(answer string) error {

		correct := strs.Any(
			options,
			func(o string) bool {
				return strings.EqualFold(answer, o)
			})

		if !correct {
			return cm.ErrorF("Answer '%s' not in '%q'.", answer, options)
		}

		return nil
	}
}

var ValidatorAnswerNotEmpty AnswerValidator = func(s string) error {
	if strs.IsEmpty(strings.TrimSpace(s)) {
		return cm.Error("Answer must not be empty.")
	}

	return nil
}

func CreateValidatorIsDirectory(tildeRepl string) AnswerValidator {
	return func(s string) error {
		s = cm.ReplaceTildeWith(s, tildeRepl)
		if !cm.IsDirectory(s) {
			return cm.Error("Answer must be an existing directory.")
		}

		return nil
	}
}
