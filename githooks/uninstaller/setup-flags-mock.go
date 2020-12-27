// +build mock

package main

import (
	cm "rycus86/githooks/common"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

func setupMockFlags(rootCmd *cobra.Command) {
	rootCmd.PersistentFlags().Bool(
		"stdin", false,
		"Use standard input to read prompt answers.")

	cm.AssertNoErrorPanic(
		viper.BindPFlag("useStdin", rootCmd.PersistentFlags().Lookup("stdin")))
}
