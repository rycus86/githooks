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

// ShowPrompt shows a prompt to the user with `text`
// with the options `shortOptions` and optional long options `longOptions`.
func (p *Context) ShowPrompt(
	text string,
	defaultAnswer string,
	allowEmpty bool) (answer string, err error) {
	return showPrompt(p, text, defaultAnswer, allowEmpty)
}
