package cmd

import (
	"github.com/spf13/cobra"
)

var panicWrongArgs = func(*cobra.Command, []string) {
	log.Panic("Wrong arguments. Use '--help' to show usage.")
}
