// +build mock

package prompt

import (
	"os"
	"strings"
)

// ShowPrompt mocks the real ShowPrompt by reading
// from the environment or if not defined calls the normal implementation.
// This is only for tests.
func (p *Context) ShowPrompt(text string,
	hintText string,
	shortOptions string,
	longOptions ...string) (answer string, err error) {

	if strings.Contains(text, "This repository wants you to trust all current") {
		answer, defined := os.LookupEnv("TRUST_ALL_HOOKS")
		if defined {
			return answer, nil
		}
	} else if strings.Contains(text, "Do you accept the changes") {
		answer, defined := os.LookupEnv("ACCEPT_CHANGES")
		if defined {
			return answer, nil
		}
	} else if strings.Contains(text, "There is a new Githooks update available") {
		answer, defined := os.LookupEnv("EXECUTE_UPDATE")
		if defined {
			return answer, nil
		}
	}

	return showPrompt(p, text, hintText, shortOptions, longOptions...)
}
