package readme

import (
	"path/filepath"
	ccm "rycus86/githooks/cmd/common"
	cm "rycus86/githooks/common"
	"rycus86/githooks/hooks"

	"github.com/spf13/cobra"
)

func updateReadme(ctx *ccm.CmdContext, panicIfExists bool) {

	repoDir, _ := ccm.AssertRepoRoot(ctx)

	file := hooks.GetReadmeFile(repoDir)

	ctx.Log.PanicIfF(panicIfExists && cm.IsFile(file),
		"This repository already seems to have a Githooks README.\n"+
			"To replace it with the latest one, please run\n"+
			"'git hooks readme update'.")

	err := hooks.WriteReadmeFile(file)
	ctx.Log.AssertNoErrorPanicF(err, "Could not write README file '%s'.", file)

	relFile, err := filepath.Rel(ctx.Cwd, file)
	if err != nil {
		relFile = file
	}
	ctx.Log.InfoF("The README file '%s' is updated.", relFile)

	if !ctx.GitX.IsBareRepo() {
		ctx.Log.Info("Do not forget to commit and push it!")
	}
}

func runAddReadme(ctx *ccm.CmdContext) {
	updateReadme(ctx, true)
}

func runUpdateReadme(ctx *ccm.CmdContext) {
	updateReadme(ctx, false)
}

func NewCmd(ctx *ccm.CmdContext) *cobra.Command {

	readmeCmd := &cobra.Command{
		Use:   "readme",
		Short: "Manages the Githooks README in the current repository.",
		Long: `Adds or updates the Githooks README in the '.githooks' folder.
This command needs to be run inside a repository.`}

	addReadmeCmd := &cobra.Command{
		Use:   "add [flags]",
		Short: `Add a Githooks README in the current repository.`,
		Long: `Adds a Githooks README in the '.githooks' folder.
It does not overwrite any files.`,
		Run: func(cmd *cobra.Command, args []string) { runAddReadme(ctx) }}

	updateReadmeCmd := &cobra.Command{
		Use:   "update [flags]",
		Short: `Update Githooks README in the current repository.`,
		Long: `Updates a Githooks README in the '.githooks' folder.
It overwrite the file if it exists already.`,
		Run: func(cmd *cobra.Command, args []string) { runUpdateReadme(ctx) }}

	readmeCmd.AddCommand(ccm.SetCommandDefaults(ctx.Log, updateReadmeCmd))
	readmeCmd.AddCommand(ccm.SetCommandDefaults(ctx.Log, addReadmeCmd))

	return ccm.SetCommandDefaults(ctx.Log, readmeCmd)
}
