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
	validator := CreateValidatorAnswerOptions(options)

	defaultAnswer := getDefaultAnswer(options)

	if p.tool != nil {

		args := append([]string{text, hintText, shortOptions}, longOptions...)
		ans, e := cm.GetOutputFromExecutableTrimmed(p.execCtx, p.tool, true, args...)
		ans = strings.ToLower(ans)

		if e == nil {

			// Validate the answer if possible.
			if validator == nil {
				return ans, nil

			} else if e := validator(ans); e == nil {
				return ans, nil
			}

			return defaultAnswer,
				cm.ErrorF("Dialog tool returned wrong answer '%s' not in '%q'",
					answer, options)
		}

		err = cm.CombineErrors(e, cm.ErrorF("Could not execute dialog script '%q'", p.tool))
		// else: Runnning fallback ...
	}

	emptyCausesDefault := strs.IsNotEmpty(defaultAnswer)
	question := p.promptFmt("%s %s [%s]: ", text, hintText, shortOptions)

	answer, isPromptDisplayed, e :=
		showPromptOptionsTerminal(
			p,
			question,
			defaultAnswer,
			options,
			emptyCausesDefault,
			validator)

	if e == nil {
		return answer, nil
	}

	if !isPromptDisplayed {
		// Show the prompt in the log output
		p.log.Info(question)
	}

	return defaultAnswer, cm.CombineErrors(err, e)
}

func showPromptOptionsTerminal(
	p *Context,
	question string,
	defaultAnswer string,
	options []string,
	emptyCausesDefault bool,
	validator AnswerValidator) (string, bool, error) {

	var err error // all errors

	nPrompts := uint(0) // How many times we showed the prompt
	maxPrompts := p.maxTries

	switch {
	case p.termIn == nil:
		err = cm.ErrorF("No terminal input available to show prompt.")
		return defaultAnswer, false, err // nolint: nlreturn
	case p.termOut == nil:
		err = cm.ErrorF("No terminal output available to show prompt.")
		return defaultAnswer, false, err // nolint: nlreturn
	}

	// Write to terminal output.
	writeOut := func(s string) error {
		_, e := p.termOut.Write([]byte(s))
		return e // nolint: nlreturn
	}

	for nPrompts < maxPrompts {

		err = writeOut(question)
		nPrompts++

		success := p.termInScanner.Scan()

		if !success {
			err = cm.CombineErrors(err,
				writeOut("\n"),
				cm.ErrorF("Could not read from terminal."))

			break
		}

		ans := p.termInScanner.Text()

		if p.printAnswer {
			_ = writeOut(strs.Fmt(" -> Received: '%s'\n", ans))
		}

		// Fallback to default answer.
		if strs.IsEmpty(ans) && emptyCausesDefault {
			ans = defaultAnswer
		}

		// Trim everything.
		ans = strings.ToLower(strings.TrimSpace(ans))

		// Validate the answer if possible.
		if validator == nil {
			return ans, true, nil
		}

		e := validator(ans)
		if e == nil {
			return ans, true, nil
		}

		warning := p.errorFmt("Answer validation error: %s", e.Error())
		err = cm.CombineErrors(err, writeOut(warning+"\n"))

		if nPrompts < maxPrompts {
			warning := p.errorFmt("Remaining tries %v.", maxPrompts-nPrompts)
			err = cm.CombineErrors(err, writeOut(warning+"\n"))
		}

	}

	warning := p.errorFmt("Could not get answer in '%q', taking default '%s'.",
		options, defaultAnswer)
	err = cm.CombineErrors(err, writeOut(warning+"\n"))

	return defaultAnswer, nPrompts != 0, err
}

// showPrompt shows a prompt to the user with `text`.
func showPrompt(
	p *Context,
	text string,
	defaultAnswer string,
	validator func(string) error) (answer string, err error) {

	cm.PanicIf(p.tool != nil, "Not yet implemented.")

	if strs.IsNotEmpty(defaultAnswer) {
		text = p.promptFmt("%s [%s]: ", text, defaultAnswer)
	} else {
		text = p.promptFmt("%s : ", text)
	}

	answer, isPromptDisplayed, e :=
		showPromptTerminal(
			p,
			text,
			defaultAnswer,
			validator)

	if e == nil {
		return answer, nil
	}

	err = cm.CombineErrors(err, e)

	if !isPromptDisplayed {
		// Show the prompt in the log output
		p.log.Info(text)
	}

	return defaultAnswer, err
}

func showPromptTerminal(
	p *Context,
	text string,
	defaultAnswer string,
	validator AnswerValidator) (string, bool, error) {

	var err error
	// Try to read from the controlling terminal if available.
	// Our stdin is never a tty (either a pipe or /dev/null when called
	// from git), so read from /dev/tty, our controlling terminal,
	// if it can be opened.
	nPrompts := uint(0) // How many times we showed the prompt
	maxPrompts := p.maxTries

	switch {
	case p.termIn == nil:
		err = cm.ErrorF("No terminal input available to show prompt.")
		return defaultAnswer, false, err // nolint: nlreturn
	case p.termOut == nil:
		err = cm.ErrorF("No terminal output available to show prompt.")
		return defaultAnswer, false, err // nolint: nlreturn
	}

	// Write to terminal output.
	writeOut := func(s string) error {
		_, e := p.termOut.Write([]byte(s))
		return e // nolint: nlreturn
	}

	for nPrompts < p.maxTries {

		err = writeOut(text)
		nPrompts++

		success := p.termInScanner.Scan()

		if !success {
			err = cm.CombineErrors(err,
				writeOut("\n"), cm.ErrorF("Could not read from terminal."))

			break
		}

		ans := p.termInScanner.Text()

		if p.printAnswer {
			_ = writeOut(strs.Fmt(" -> Received: '%s'\n", ans))
		}

		if strs.IsEmpty(ans) {
			// User pressed `Enter`
			ans = defaultAnswer
		}

		// Trim everything.
		ans = strings.ToLower(strings.TrimSpace(ans))

		// Validate the answer if possible.
		if validator == nil {
			return ans, true, nil
		}

		e := validator(ans)
		if e == nil {
			return ans, true, nil
		}

		warning := p.errorFmt("Answer validation error: %s", e.Error())
		err = cm.CombineErrors(err, writeOut(warning+"\n"))

		if nPrompts < maxPrompts {
			warning := p.errorFmt("Remaining tries %v.", maxPrompts-nPrompts)
			err = cm.CombineErrors(err, writeOut(warning+"\n"))
		} else if p.panicIfMaxTries {
			p.log.PanicF("Could not validate answer in '%v' tries.", maxPrompts)
		}
	}

	warning := p.errorFmt("Could not get answer, taking default '%s'.", defaultAnswer)
	err = cm.CombineErrors(err, writeOut(warning+"\n"))

	return defaultAnswer, nPrompts != 0, err
}

func showPromptMulti(
	p *Context,
	text string,
	validator AnswerValidator) (answers []string, err error) {

	cm.PanicIf(p.tool != nil, "Not yet implemented.")

	doParse := true

	// Write to terminal output.
	writeOut := func(s string) error {
		_, e := p.termOut.Write([]byte(s))
		return e // nolint: nlreturn
	}

	ans := ""
	isPromptDisplayed := false
	prompt := p.promptFmt(text + " : ")

	for doParse {

		ans, isPromptDisplayed, err = showPromptTerminal(p, prompt, "", nil)

		if err == nil {

			if strs.IsEmpty(ans) {

				doParse = false
				continue // nolint: nlreturn

			} else if validator != nil {
				// Validate the answer if possible.
				if e := validator(ans); e != nil {
					_ = writeOut(p.errorFmt("Entry validation error: %s", e.Error()))
					continue // nolint: nlreturn
				}
			}

			// Add the entry.
			answers = append(answers, ans)

		} else {
			doParse = false

			if !isPromptDisplayed {
				// Show the prompt in the log output
				p.log.Info(text)
			}
		}
	}

	return
}
