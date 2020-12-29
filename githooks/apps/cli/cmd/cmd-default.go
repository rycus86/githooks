package cmd

import "github.com/spf13/cobra"

func SetCommandDefaults(cmd *cobra.Command) *cobra.Command {
	cmd.DisableFlagsInUseLine = true
	cmd.SilenceUsage = true
	cmd.SilenceErrors = true

	return cmd
}
