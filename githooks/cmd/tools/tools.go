package tools

import (
	"os"
	"path"
	"path/filepath"
	ccm "rycus86/githooks/cmd/common"
	cm "rycus86/githooks/common"
	"rycus86/githooks/hooks"
	strs "rycus86/githooks/strings"

	"github.com/spf13/cobra"
)

func runToolsRegister(ctx *ccm.CmdContext, args []string) {

	tool := args[0]
	dir := args[1]

	ctx.Log.PanicIfF(unregister(ctx, tool, true) != nil, "Could not unregister tool '%s'.", tool)

	targetDir := hooks.GetToolDir(ctx.InstallDir, tool)
	rootDir := path.Dir(targetDir)
	err := os.MkdirAll(rootDir, cm.DefaultFileModeDirectory)
	ctx.Log.AssertNoErrorPanicF(err, "Could not registration tool '%s'.", tool)

	err = cm.CopyDirectory(dir, targetDir)
	ctx.Log.AssertNoErrorPanicF(err, "Could not registration tool '%s'.", tool)

	ctx.Log.Info("Installed tool '%s'.", tool)
}

func unregister(ctx *ccm.CmdContext, tool string, quiet bool) error {

	targetDir := hooks.GetToolDir(ctx.InstallDir, tool)

	if cm.IsDirectory(targetDir) {
		if err := os.RemoveAll(targetDir); err != nil {
			return err
		}

		if !quiet {
			ctx.Log.Info("The tool '%s' is uninstalled.", tool)
		}
	}

	if !quiet {
		ctx.Log.ErrorF("The tool '%s' is not installed.", tool)
	}

	return nil
}

func runToolsUnregister(ctx *ccm.CmdContext, args []string) {

	tool := args[0]
	err := unregister(ctx, tool, false)
	ctx.Log.AssertNoErrorPanicF(err, "Could not unregister tool '%s'.", tool)
}

func validateTool(log cm.ILogContext, nArgs int) func(cmd *cobra.Command, args []string) {
	return func(c *cobra.Command, args []string) {
		ccm.PanicIfNotExactArgs(log, nArgs)(c, args)

		cm.PanicIfF(!strs.Includes([]string{"dialog"}, args[0]),
			"Tool '%s' is not supported!", args[0])

		if len(args) == 2 { //nolint: gomnd

			args[1] = filepath.ToSlash(args[1])
			runFile := path.Join(args[1], "run")

			cm.PanicIfF(!cm.IsDirectory(args[1]),
				"Tool directory '%s' does not exist!", args[1])

			cm.PanicIfF(!cm.IsFile(path.Join(args[1], "run")),
				"Tool run file '%s' does not exist!", runFile)

		}
	}
}

func NewCmd(ctx *ccm.CmdContext) *cobra.Command {

	var toolsCmd = &cobra.Command{
		Use:   "tools",
		Short: "Manages script folders for tools.",
		Long: strs.Fmt(`Manages script folders for tools.

Currently the following tools are supported:

#### Dialog Tool ('<toolName>' = 'dialog')

The interface of the dialog tool is as follows:

If 'run' is executable, then the following is executed`+"\n\n"+
			ccm.FormatCodeBlock(`$ run <title> <text> <options> <long-options>...`, "shell")+"\n\n"+
			`otherwise, assuming 'run' is a shell script, the following is executed`+"\n\n"+
			ccm.FormatCodeBlock(`$ sh run <title> <text> <options> <long-options>...`, "shell")+"\n\n"+
			`The arguments of the dialog tool are:

%[1]s '<title>' is the title for the GUI dialog
%[1]s '<text>' is the text for the GUI dialog
%[1]s '<short-options>' are the button return values, slash-delimited,
  e.g. 'Y/n/d'. The default button is the first capital character found.
%[1]s '<long-options>...' are the button texts in the GUI,
  e.g. 'Yes', 'no', 'disable'.

The script needs to return one of the short-options on 'stdout'.
Non-zero exit code triggers the fallback of reading from 'stdin'.`, ccm.ListItemLiteral)}

	var registerCmd = &cobra.Command{
		Use:   "register [flags] <toolName> <scriptFolder>",
		Short: `Register a tool.`,
		Long: `Install the script folder '<scriptFolder>' in
the installation directory under 'tools/<toolName>'.`,
		Run: func(cmd *cobra.Command, args []string) {
			runToolsRegister(ctx, args)
		}}

	var unregisterCmd = &cobra.Command{
		Use:   "unregister [flags] <toolName>",
		Short: `Unregister a tool.`,
		Long: `Uninstall the script folder in the installation
directory under 'tools/<toolName>'.`,
		Run: func(cmd *cobra.Command, args []string) {
			runToolsUnregister(ctx, args)
		}}

	registerCmd.PreRun = validateTool(ctx.Log, 2)   //nolint: gomnd
	unregisterCmd.PreRun = validateTool(ctx.Log, 1) //nolint: gomnd

	toolsCmd.AddCommand(ccm.SetCommandDefaults(ctx.Log, registerCmd))
	toolsCmd.AddCommand(ccm.SetCommandDefaults(ctx.Log, unregisterCmd))

	return toolsCmd
}
