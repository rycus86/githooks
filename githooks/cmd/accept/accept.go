package accept

import (
	ccm "rycus86/githooks/cmd/common"

	"github.com/spf13/cobra"
)

func runAccept(ctx *ccm.CmdContext) {

}

func NewCmd(ctx *ccm.CmdContext) *cobra.Command {

	// acceptCmd represents the accept command.
	var acceptCmd = &cobra.Command{
		Use:   "accept",
		Short: "Accepts a new hook or changes to an existing hook.",
		Long: `
Accepts a new hook or changes to an existing hook.

git hooks accept [--shared] [trigger] [hook-script]
git hooks accept [--shared] [hook-script]
git hooks accept [--shared] [trigger]

Accepts a new hook or changes to an existing hook.
The 'trigger' parameter should be the name of the Git event if given.
The 'hook-script' can be the name of the file to enable, or its
relative path, or an absolute path, we will try to find it.
If the '--shared' parameter is given as the first argument,
hooks in the shared repositories will be accepted,
otherwise they are looked up in the current local repository.`,
		Run: func(cmd *cobra.Command, args []string) { runAccept(ctx) },
	}

	return ccm.SetCommandDefaults(ctx.Log, acceptCmd)
}
