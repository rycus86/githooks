package main

import (
	hooks "rycus86/githooks/githooks"
	"rycus86/githooks/prompt"
)

// UISettings defines user interface settings made by the user over prompts.
type UISettings struct {

	// A prompt context which enables showing a prompt.
	PromptCtx prompt.IContext

	// The user accepts all newly/changed hooks as trusted.
	AcceptAllChanges bool

	// All hooks which were newly trusted and need to be recorded back
	TrustedHooks []hooks.ChecksumResult

	// All hooks which were newly disabled and need to be recored back
	DisabledHooks []hooks.ChecksumResult
}

// AppendTrustedHook appends trusted hooks.
func (s *UISettings) AppendTrustedHook(checksum ...hooks.ChecksumResult) {
	s.TrustedHooks = append(s.TrustedHooks, checksum...)
}

// AppendDisabledHook appends disabled hooks.
func (s *UISettings) AppendDisabledHook(checksum ...hooks.ChecksumResult) {
	s.DisabledHooks = append(s.DisabledHooks, checksum...)
}
