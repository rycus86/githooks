//nolint: gomnd
package cmd

import (
	"os"
	"path"
	"path/filepath"
	cm "rycus86/githooks/common"
	"rycus86/githooks/hooks"
	strs "rycus86/githooks/strings"

	"github.com/spf13/cobra"
)

// toolsCmd represents the tools command.
var toolsCmd = &cobra.Command{
	Use:   "tools",
	Short: "Manages script folders for tools.",
	Long: `Manages script folders for tools.

Currently the following tools are supported:

>> Dialog Tool (<toolName> = "dialog")

  The interface of the dialog tool is as follows.

  - if 'run' is executable
      $ run <title> <text> <options> <long-options>
  - otherwise, assuming 'run' is a shell script
      $ sh run <title> <text> <options> <long-options>

  The arguments of the dialog tool are:
  - '<title>' the title for the GUI dialog
  - '<text>' the text for the GUI dialog
  - '<short-options>' the button return values, slash-delimited,
      e.g. 'Y/n/d'.
      The default button is the first capital character found.
  - '<long-options>' the button texts in the GUI,
      e.g. 'Yes/no/disable'

  The script needs to return one of the short-options on 'stdout'.
  Non-zero exit code triggers the fallback of reading from 'stdin'.`}

var registerCmd = &cobra.Command{
	Use:   "register [flags] <toolName> <scriptFolder>",
	Short: `Register a tool.`,
	Long: `Install the script folder '<scriptFolder>' in
the installation directory under 'tools/<toolName>'.`,
	Run: runToolsRegister}

var unregisterCmd = &cobra.Command{
	Use:   "unregister [flags] <toolName>",
	Short: `Unregister a tool.`,
	Long: `Uninstall the script folder in the installation
directory under 'tools/<toolName>'.`,
	Run: runToolsUnregister}

func runToolsRegister(cmd *cobra.Command, args []string) {

	tool := args[0]
	dir := args[1]

	log.PanicIfF(unregister(tool, true) != nil, "Could not unregister tool '%s'.", tool)

	targetDir := hooks.GetToolDir(settings.InstallDir, tool)
	rootDir := path.Dir(targetDir)
	err := os.MkdirAll(rootDir, cm.DefaultFileModeDirectory)
	log.AssertNoErrorPanicF(err, "Could not registration tool '%s'.", tool)

	err = cm.CopyDirectory(dir, targetDir)
	log.AssertNoErrorPanicF(err, "Could not registration tool '%s'.", tool)

	log.Info("Installed tool '%s'.", tool)
}

func unregister(tool string, quiet bool) error {

	targetDir := hooks.GetToolDir(settings.InstallDir, tool)

	if cm.IsDirectory(targetDir) {
		if err := os.RemoveAll(targetDir); err != nil {
			return err
		}

		if !quiet {
			log.Info("The tool '%s' is uninstalled.", tool)
		}
	}

	if !quiet {
		log.ErrorF("The tool '%s' is not installed.", tool)
	}

	return nil
}

func runToolsUnregister(cmd *cobra.Command, args []string) {

	tool := args[0]
	err := unregister(tool, false)
	log.AssertNoErrorPanicF(err, "Could not unregister tool '%s'.", tool)
}

func validateTool(nArgs int) func(cmd *cobra.Command, args []string) {
	return func(cmd *cobra.Command, args []string) {
		panicIfNotExactArgs(nArgs)(cmd, args)

		cm.PanicIfF(!strs.Includes([]string{"dialog"}, args[0]),
			"Tool '%s' is not supported!", args[0])

		if len(args) == 2 {

			args[1] = filepath.ToSlash(args[1])
			runFile := path.Join(args[1], "run")

			cm.PanicIfF(!cm.IsDirectory(args[1]),
				"Tool directory '%s' does not exist!", args[1])

			cm.PanicIfF(!cm.IsFile(path.Join(args[1], "run")),
				"Tool run file '%s' does not exist!", runFile)

		}
	}
}

func init() { // nolint: gochecknoinits

	registerCmd.PreRun = validateTool(2)   //nolint: gomnd
	unregisterCmd.PreRun = validateTool(1) //nolint: gomnd

	toolsCmd.AddCommand(setCommandDefaults(registerCmd))
	toolsCmd.AddCommand(setCommandDefaults(unregisterCmd))
	rootCmd.AddCommand(setCommandDefaults(toolsCmd))
}
