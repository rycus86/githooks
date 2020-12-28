package cmd

import (
	"github.com/spf13/cobra"
)

// toolsCmd represents the tools command.
var toolsCmd = &cobra.Command{
	Use:   "tools",
	Short: "Manages script folders for tools.",
	Long: `
Manages script folders for tools.

git hooks tools register <toolName> <scriptFolder>

	Install the script folder '<scriptFolder>' in
	the installation directory under 'tools/<toolName>'.

git hooks tools unregister <toolName>

	Uninstall the script folder in the installation
	directory under 'tools/<toolName>'.


Currently the following tools are supported:

	>> Dialog Tool (<toolName> = \"dialog\")

	The interface of the dialog tool is as follows.

	# if 'run' is executable
	\$ run <title> <text> <options> <long-options>
	# otherwise, assuming 'run' is a shell script
	\$ sh run <title> <text> <options> <long-options>

	The arguments of the dialog tool are:
	- '<title>' the title for the GUI dialog
	- '<text>' the text for the GUI dialog
	- '<short-options>' the button return values, slash-delimited,
		e.g. 'Y/n/d'.
		The default button is the first capital character found.
	- '<long-options>' the button texts in the GUI,
		e.g. 'Yes/no/disable'

	The script needs to return one of the short-options on 'stdout'.
	Non-zero exit code triggers the fallback of reading from 'stdin'.`,
	Run: runTools,
}

func runTools(cmd *cobra.Command, args []string) {

}

func init() { // nolint: gochecknoinits
	rootCmd.AddCommand(toolsCmd)
}
