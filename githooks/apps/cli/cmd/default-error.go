package cmd

import (
	cm "rycus86/githooks/common"

	"github.com/spf13/cobra"
)

var ValidationErr = cm.Error("Wrong arguments. Use '--help' to show usage.")
var RuntimeErr = cm.Error("Command error. Use '--help' to show usage.")

var noSubcommandGiven = func(*cobra.Command, []string) error {
	return ValidationError("No subcommand given.")
}

func ValidationError(format string, args ...interface{}) error {
	log.ErrorF(format, args...)

	return ValidationErr
}
