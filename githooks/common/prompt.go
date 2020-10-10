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
	execCtx  IExecContext
	toolPath string
}

// Close closes the prompt context
func (p *PromptContext) Close() {

	if f, ok := p.termIn.(*os.File); ok {
		f.Close()
	}
}

// CreatePromptContext creates a `PrompContext`.
func CreatePromptContext(log ILogContext,
	execCtx IExecContext, toolPath string) (IPromptContext, error) {
	terminalReader, err := GetCtty()

	p := PromptContext{
		log: log,

		promptFmt: log.GetPromptFormatter(),
		termOut:   log.GetInfoWriter(),
		termIn:    terminalReader,

		execCtx:  execCtx,
		toolPath: toolPath}

	if terminalReader != nil {
		runtime.SetFinalizer(&p, func(p *PromptContext) { p.Close() })
	}

	return &p, err
}

func getDefaultAnswer(shortOptions string) string {
	for _, r := range strings.Split(shortOptions, "/") {
		if strings.ToLower(r) != r {
			return r
		}
	}
	return ""
}

func isAnswerCorrect(answer string, shortOptions string) bool {
	return strs.Includes(strings.Split(shortOptions, "/"), answer)
}

// ShowPrompt shows a prompt to the user with `text`
// with the options `shortOptions` and optional long options `longOptions`.
func (p *PromptContext) ShowPrompt(text string,
	hintText string,
	shortOptions string,
	longOptions ...string) (answer string, err error) {

	defaultAnswer := getDefaultAnswer(shortOptions)

	if strs.IsNotEmpty(p.toolPath) {

		answer, err = ExecuteScript(p.execCtx,
			p.toolPath, true,
			append([]string{text, hintText, shortOptions},
				longOptions...)...)

		if err == nil {
			if isAnswerCorrect(answer, shortOptions) {
				return answer, nil
			}

			return defaultAnswer,
				ErrorF("Dialog tool returned wrong answer '%s' not in '%q'",
					answer, shortOptions)
		}

		err = CombineErrors(err, ErrorF("Could not execute dialog script '%s'", p.toolPath))
		// else: Runnning fallback ...
	}

	enterCausesDefault := strs.IsNotEmpty(defaultAnswer)

	// Try to read from the controlling terminal if available.
	// Our stdin is never a tty (either a pipe or /dev/null when called
	// from git), so read from /dev/tty, our controlling terminal,
	// if it can be opened.
	nPrompts := 0 // How many times we showed the prompt
	question := p.promptFmt("%s %s [%s]: ", text, hintText, shortOptions)

	if p.termIn != nil {
		maxPrompts := 3
		answerIncorrect := true
		for answerIncorrect && nPrompts < maxPrompts {

			p.termOut.Write([]byte(question))
			nPrompts++

			var ans string
			reader := bufio.NewReader(p.termIn)
			ans, e := reader.ReadString('\n')

			if e == nil {
				answer = strings.TrimSpace(ans)

				if strs.IsEmpty(answer) && enterCausesDefault {
					answer = defaultAnswer
				}

				if isAnswerCorrect(answer, shortOptions) {
					p.log.LogDebugF("Answer '%v' received.", answer)
					return answer, nil
				}

				warning := p.promptFmt("Answer '%s' not in '%q', try again ...", answer, shortOptions)
				p.termOut.Write([]byte(warning))

			} else {
				p.termOut.Write([]byte("\n"))
				err = CombineErrors(err, ErrorF("Could not read from terminal reader."))
				break
			}
		}
	} else {
		err = CombineErrors(err, ErrorF("Do not have a controlling terminal to show prompt."))
	}

	if nPrompts == 0 {
		// Show the prompt once ...
		p.termOut.Write([]byte(question))
	}

	p.log.LogDebugF("Answer not received -> Using default '%s'", defaultAnswer)
	return defaultAnswer, err
}
