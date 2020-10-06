package hooks

import (
	"bufio"
	"fmt"
	"os"
	cm "rycus86/githooks/common"
	strs "rycus86/githooks/strings"
	"strings"

	"github.com/gookit/color"
	"github.com/mattn/go-isatty"
)

func isTerminal() bool {
	return isatty.IsTerminal(os.Stdout.Fd())
}

// ShowPrompt shows a prompt to the user with `text`
// with the options `shortOptions` and optional long options `longOptions`.
func ShowPrompt(
	execCtx cm.ExecContext,
	installDir string,
	text string,
	hintText string,
	shortOptions string,
	longOptions ...string) (string, error) {

	var err error
	dialogTool := GetToolScript(installDir, "dialog")

	if dialogTool != "" {

		answer, e := cm.ExecuteScript(execCtx,
			dialogTool, true,
			append([]string{"githooks::", text, hintText,
				shortOptions},
				longOptions...)...)

		if e == nil {
			if !strs.Includes(strings.Split(shortOptions, "/"), answer) {
				return "", cm.ErrorF("Dialog tool returned wrong answer '%s'", answer)
			}
			return answer, nil
		}

		err = cm.ErrorF("Could not execute dialog script '%s'", dialogTool)
		// else: Runnning fallback ...
	}

	// Try to read from `dev/tty` if available.
	// Our stdin is never a tty (either a pipe or /dev/null when called
	// from git), so read from /dev/tty, our controlling terminal,
	// if it can be opened.
	if isTerminal() {

		text := cm.FormatMessageF("❓ Githooks: ", "   ", "%s %s [%s]: ",
			text, hintText, shortOptions)
		if color.IsSupportColor() {
			text = color.FgGreen.Render(text)
		}
		fmt.Print(text)

		var answer string
		reader := bufio.NewReader(os.Stdin)
		answer, e := reader.ReadString('\n')

		// For visual separation
		fmt.Print("\n")

		if e == nil {

			// For debugging ...
			if cm.PrintPromptAnswer {
				fmt.Printf("Githooks: answer: '%s'\n", strings.TrimSpace(answer))
			}

			return strings.TrimSpace(answer), nil
		}

		err = cm.CombineErrors(err, cm.Error("Could not read answer from stdin"))
	}

	return "", err
}
