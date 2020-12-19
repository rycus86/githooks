package prompt

import (
	cm "rycus86/githooks/common"
	strs "rycus86/githooks/strings"
	"strings"
)

// showPromptOptions shows a prompt to the user with `text`
// with the options `shortOptions` and optional long options `longOptions`.
func showPromptOptions(
	p *Context,
	text string,
	hintText string,
	shortOptions string,
	longOptions ...string) (answer string, err error) {

	options := strings.Split(shortOptions, "/")
	defaultAnswer := getDefaultAnswer(options)

	if p.tool != nil {

		args := append([]string{text, hintText, shortOptions}, longOptions...)
		answer, err = cm.GetOutputFromExecutableTrimmed(p.execCtx, p.tool, true, args...)
		answer = strings.ToLower(answer)

		if err == nil {
			if isAnswerCorrect(answer, options) {
				return
			}

			return defaultAnswer,
				cm.ErrorF("Dialog tool returned wrong answer '%s' not in '%q'",
					answer, options)
		}

		err = cm.CombineErrors(err, cm.ErrorF("Could not execute dialog script '%q'", p.tool))
		// else: Runnning fallback ...
	}

	emptyCausesDefault := strs.IsNotEmpty(defaultAnswer)
	question := p.promptFmt("%s %s [%s]: ", text, hintText, shortOptions)

	answer, isPromptDisplayed, e := p.showPromptOptionsTerminal(
		question,
		defaultAnswer,
		options,
		emptyCausesDefault)

	if e == nil {
		return answer, nil
	}

	err = cm.CombineErrors(err, e)

	if !isPromptDisplayed {
		// Show the prompt in the log output
		p.log.Info(question)
	}

	p.log.DebugF("Answer not received -> Using default '%s'", defaultAnswer)
	return defaultAnswer, err
}

func (p *Context) showPromptOptionsTerminal(
	question string,
	defaultAnswer string,
	options []string,
	emptyCausesDefault bool) (string, bool, error) {

	var err error
	// Try to read from the controlling terminal if available.
	// Our stdin is never a tty (either a pipe or /dev/null when called
	// from git), so read from /dev/tty, our controlling terminal,
	// if it can be opened.
	nPrompts := 0 // How many times we showed the prompt
	maxPrompts := 3

	if p.termIn != nil && p.termOut != nil {

		for nPrompts < maxPrompts {

			p.termOut.Write([]byte(question))
			nPrompts++

			success := p.termInScanner.Scan()

			if success {
				ans := strings.ToLower(strings.TrimSpace(p.termInScanner.Text()))

				if p.printAnswer {
					p.termOut.Write([]byte(strs.Fmt(" -> Received: '%s'\n", ans)))
				}

				if strs.IsEmpty(ans) && emptyCausesDefault {
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
				err = cm.ErrorF("Could not read from terminal.")
				break
			}
		}

		warning := p.promptFmt("Could not get answer in '%q', taking default '%s'", options, defaultAnswer)
		p.termOut.Write([]byte(warning + "\n"))

	} else {
		err = cm.ErrorF("Do not have a controlling terminal to show prompt.")
	}

	return defaultAnswer, nPrompts != 0, err
}

// showPrompt shows a prompt to the user with `text`.
func showPrompt(
	p *Context,
	text string,
	defaultAnswer string,
	allowEmpty bool) (answer string, err error) {

	cm.PanicIf(p.tool != nil, "Not yet implemented.")

	question := ""
	emptyCausesDefault := false

	if strs.IsNotEmpty(defaultAnswer) {
		emptyCausesDefault = true
		question = p.promptFmt("%s [%s]: ", text, defaultAnswer)
	} else {
		question = p.promptFmt("%s : ", text)
	}

	answer, isPromptDisplayed, e :=
		p.showPromptTerminal(
			question,
			defaultAnswer,
			emptyCausesDefault,
			allowEmpty)

	if e == nil {
		return answer, nil
	}

	err = cm.CombineErrors(err, e)

	if !isPromptDisplayed {
		// Show the prompt in the log output
		p.log.Info(question)
	}

	p.log.DebugF("Answer not received -> Using default '%s'", defaultAnswer)
	return defaultAnswer, err
}

func (p *Context) showPromptTerminal(
	question string,
	defaultAnswer string,
	emptyCausesDefault bool,
	allowEmpty bool) (string, bool, error) {

	var err error
	// Try to read from the controlling terminal if available.
	// Our stdin is never a tty (either a pipe or /dev/null when called
	// from git), so read from /dev/tty, our controlling terminal,
	// if it can be opened.
	nPrompts := 0 // How many times we showed the prompt
	maxPrompts := 3

	if p.termIn != nil && p.termOut != nil {

		for nPrompts < maxPrompts {

			p.termOut.Write([]byte(question))
			nPrompts++

			success := p.termInScanner.Scan()

			if success {
				ans := strings.ToLower(strings.TrimSpace(p.termInScanner.Text()))

				if p.printAnswer {
					p.termOut.Write([]byte(strs.Fmt(" -> Received: '%s'\n", ans)))
				}

				if strs.IsEmpty(ans) && emptyCausesDefault {
					ans = defaultAnswer
				}

				if strs.IsNotEmpty(ans) || allowEmpty {
					return ans, nPrompts != 0, nil
				}

				if nPrompts < maxPrompts {
					warning := p.promptFmt("Answer is empty, try again ...")
					p.termOut.Write([]byte(warning + "\n"))
				}

			} else {
				p.termOut.Write([]byte("\n"))
				err = cm.ErrorF("Could not read from terminal.")
				break
			}
		}

		warning := p.promptFmt("Could not get non-empty answer, taking default '%s'", defaultAnswer)
		p.termOut.Write([]byte(warning + "\n"))

	} else {
		err = cm.ErrorF("Do not have a controlling terminal to show prompt.")
	}

	return defaultAnswer, nPrompts != 0, err
}
