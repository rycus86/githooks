package main

import (
	"os"
	"path/filepath"
	"rycus86/githooks/cmd"
	cm "rycus86/githooks/common"
	"rycus86/githooks/hooks"
)

func main() {

	cwd, err := os.Getwd()
	cm.AssertNoErrorPanic(err, "Could not get current working dir.")
	cwd = filepath.ToSlash(cwd)

	log, err := cm.CreateLogContext(false)
	cm.AssertOrPanic(err == nil, "Could not create log")

	exitCode := 0
	defer func() { os.Exit(exitCode) }()

	// Handle all panics and report the error
	defer func() {
		r := recover()
		if hooks.HandleCLIErrors(r, cwd, log) {
			exitCode = 1
		}
	}()

	cmd.Run(log)
}
