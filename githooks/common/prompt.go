package common

import (
	"bufio"
	"io"
	"os"
	"runtime"
	strs "rycus86/githooks/strings"
	"strings"
)

// IPromptContext defines the interface to show a prompt to the user
type IPromptContext interface {
	ShowPrompt(text string,
		hintText string,
		shortOptions string,
		longOptions ...string) (string, error)
	Close()
}

// PromptFormatter is the format function to format a prompt.
type PromptFormatter func(format string, args ...interface{}) string

// PromptContext defines the prompt context based on a `ILogContext`
// or as a fallback using the defined dialog tool if configured.
type PromptContext struct {
	log ILogContext

	// Fallback prompt over the log context if available.
	promptFmt PromptFormatter
	termOut   io.Writer
	termIn    io.Reader

	// Prompt over the tool script if existing.
	execCtx IExecContext
	tool    *Executable
}

// Close closes the prompt context
func (p *PromptContext) Close() {

	if f, ok := p.termIn.(*os.File); ok {
		f.Close()
	}
}

// CreatePromptContext creates a `PrompContext`.
func CreatePromptContext(
	log ILogContext,
	execCtx IExecContext,
	tool *Executable) (IPromptContext, error) {

	var terminalWriter io.Writer
	if log.IsInfoATerminal() {
		terminalWriter = log.GetInfoWriter()
	}
	terminalReader, err := GetCtty()

	p := PromptContext{
		log: log,

		promptFmt: log.GetPromptFormatter(),
		termOut:   terminalWriter,
		termIn:    terminalReader,

		execCtx: execCtx,
		tool:    tool}

	if terminalReader != nil {
		runtime.SetFinalizer(&p, func(p *PromptContext) { p.Close() })
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
	return strs.Includes(options, answer)
}

// ShowPrompt shows a prompt to the user with `text`
// with the options `shortOptions` and optional long options `longOptions`.
func (p *PromptContext) ShowPrompt(text string,
	hintText string,
	shortOptions string,
	longOptions ...string) (answer string, err error) {

	options := strings.Split(shortOptions, "/")
	defaultAnswer := getDefaultAnswer(options)

	if p.tool != nil {

		args := append([]string{text, hintText, shortOptions}, longOptions...)
		answer, err = GetOutputFromExecutableTrimmed(p.execCtx, p.tool, true, args...)

		if err == nil {
			if isAnswerCorrect(answer, options) {
				return
			}

			return defaultAnswer,
				ErrorF("Dialog tool returned wrong answer '%s' not in '%q'",
					answer, options)
		}

		err = CombineErrors(err, ErrorF("Could not execute dialog script '%q'", p.tool))
		// else: Runnning fallback ...
	}

	enterCausesDefault := strs.IsNotEmpty(defaultAnswer)
	question := p.promptFmt("%s %s [%s]: ", text, hintText, shortOptions)

	answer, isPromptDisplayed, e := p.showPromptTerminal(
		question,
		defaultAnswer,
		options,
		enterCausesDefault)
	if e == nil {
		return answer, nil
	}

	err = CombineErrors(err, e)

	if !isPromptDisplayed {
		// Show the prompt in the log output
		p.log.LogInfo(question)
	}

	p.log.LogDebugF("Answer not received -> Using default '%s'", defaultAnswer)
	return defaultAnswer, err
}

func (p *PromptContext) showPromptTerminal(
	question string,
	defaultAnswer string,
	options []string,
	enterCausesDefault bool) (string, bool, error) {

	var err error
	// Try to read from the controlling terminal if available.
	// Our stdin is never a tty (either a pipe or /dev/null when called
	// from git), so read from /dev/tty, our controlling terminal,
	// if it can be opened.
	nPrompts := 0 // How many times we showed the prompt

	if p.termIn != nil && p.termOut != nil {

		maxPrompts := 3
		answerIncorrect := true

		for answerIncorrect && nPrompts < maxPrompts {

			p.termOut.Write([]byte(question))
			nPrompts++

			reader := bufio.NewReader(p.termIn)
			ans, e := reader.ReadString('\n')

			if e == nil {
				ans := strings.TrimSpace(ans)

				if strs.IsEmpty(ans) && enterCausesDefault {
					ans = defaultAnswer
				}

				if isAnswerCorrect(ans, options) {
					return ans, nPrompts != 0, nil
				}

				if nPrompts < maxPrompts {
					warning := p.promptFmt("Answer '%s' not in '%q', try again ...", ans, options)
					p.termOut.Write([]byte(warning + "\n"))
				}

			} else {
				p.termOut.Write([]byte("\n"))
				err = ErrorF("Could not read from terminal.")
				break
			}
		}

		warning := p.promptFmt("Could not get answer in '%q', taking default '%s'", options, defaultAnswer)
		p.termOut.Write([]byte(warning + "\n"))

	} else {
		err = ErrorF("Do not have a controlling terminal to show prompt.")
	}

	return defaultAnswer, nPrompts != 0, err
}
