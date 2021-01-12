package main

// Arguments repesents all CLI arguments for the uninstaller.
type Arguments struct {
	Config string

	InternalPostDispatch bool

	NonInteractive bool

	UseStdin bool
}
