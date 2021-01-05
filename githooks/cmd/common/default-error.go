package ccm

import (
	"math"
	cm "rycus86/githooks/common"

	"github.com/spf13/cobra"
)

func PanicWrongArgs(log cm.ILogContext) func(cmd *cobra.Command, args []string) {
	return func(cmd *cobra.Command, args []string) {
		_ = cmd.Help()
		log.Panic("Wrong arguments.")
	}
}

func PanicIfAnyArgs(log cm.ILogContext) func(cmd *cobra.Command, args []string) {
	return func(cmd *cobra.Command, args []string) {
		if len(args) != 0 {
			_ = cmd.Help()
			log.Panic("Wrong arguments.")
		}
	}
}

func PanicIfNotExactArgs(log cm.ILogContext, nArgs int) func(cmd *cobra.Command, args []string) {
	return func(cmd *cobra.Command, args []string) {
		err := cobra.ExactArgs(nArgs)(cmd, args)
		if err != nil {
			_ = cmd.Help()
		}
		log.AssertNoErrorPanic(err, "Wrong arguments:")
	}
}

func PanicIfNotRangeArgs(log cm.ILogContext, nMinArgs int, nMaxArgs int) func(cmd *cobra.Command, args []string) {
	return func(cmd *cobra.Command, args []string) {
		if nMaxArgs < 0 {
			nMaxArgs = math.MaxInt32
		}
		err := cobra.RangeArgs(nMinArgs, nMaxArgs)(cmd, args)
		if err != nil {
			_ = cmd.Help()
		}
		log.AssertNoErrorPanic(err, "Wrong arguments:")
	}
}
