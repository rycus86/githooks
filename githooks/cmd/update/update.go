package update

import (
	ccm "rycus86/githooks/cmd/common"

	"github.com/spf13/cobra"
)

func runUpdate(ctx *ccm.CmdContext) {

}

func NewCmd(ctx *ccm.CmdContext) *cobra.Command {

	updateCmd := &cobra.Command{
		Use:   "update",
		Short: "Performs an update check.",
		Long: `
Executes an update check for a newer Githooks version.

git hooks update [force]
git hooks update [enable|disable]

	If it finds one, or if 'force' was given, the downloaded
	install script is executed for the latest version.
	The 'enable' and 'disable' options enable or disable
	the automatic checks that would normally run daily
	after a successful commit event.`,
		Run: func(cmd *cobra.Command, args []string) {
			runUpdate(ctx)
		},
	}

	return ccm.SetCommandDefaults(ctx.Log, updateCmd)
}
