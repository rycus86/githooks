// +build !mock

package prompt

// ShowPrompt shows a prompt to the user with `text`
// with the options `shortOptions` and optional long options `longOptions`.
func (p *Context) ShowPrompt(text string,
	hintText string,
	shortOptions string,
	longOptions ...string) (answer string, err error) {
	return showPrompt(p, text, hintText, shortOptions, longOptions...)
}
