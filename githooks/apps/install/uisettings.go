package install

import (
	"rycus86/githooks/prompt"
)

// UISettings defines user interface settings made by the user over prompts.
type UISettings struct {

	// A prompt context which enables showing a prompt.
	PromptCtx prompt.IContext

	// Cached answer for the readme setup prompt.
	AnswerSetupIncludedReadme string

	// Cached answer for the LFS detection prompt.
	DeleteDetectedLFSHooks string
}
