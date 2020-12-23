// +build !mock

package prompt

// ShowPromptOptions shows a prompt to the user with `text`
// with the options `shortOptions` and optional long options `longOptions`.
func (p *Context) ShowPromptOptions(text string,
	hintText string,
	shortOptions string,
	longOptions ...string) (answer string, err error) {
	return showPromptOptions(p, text, hintText, shortOptions, longOptions...)
}

// ShowPrompt shows a prompt to enter an answer and
// validates it with a validator.
func (p *Context) ShowPrompt(
	text string,
	defaultAnswer string,
	validator AnswerValidator) (answer string, err error) {
	return showPrompt(p, text, defaultAnswer, validator)
}

// ShowPromptMulti shows multiple prompts to enter multiple answers and
// validates it with a validator. An empty answer exits the prompt.
func (p *Context) ShowPromptMulti(
	text string,
	validator AnswerValidator) (answers []string, err error) {
	return showPromptMulti(p, text, validator)
}
