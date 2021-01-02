package cmd

import (
	"path/filepath"
	cm "rycus86/githooks/common"
	"rycus86/githooks/hooks"

	"github.com/spf13/cobra"
)

// readmeCmd represents the readme command.
var readmeCmd = &cobra.Command{
	Use:   "readme",
	Short: "Manages the Githooks README in the current repository.",
	Long: `Adds or updates the Githooks README in the '.githooks' folder.
This command needs to be run inside a repository.`}

var addReadmeCmd = &cobra.Command{
	Use:   "add [flags]",
	Short: `Register a tool.`,
	Long: `Adds a Githooks Readme in the '.githooks' folder.
It does not overwrite any files.`,
	Run: runAddReadme}

var updateReadmeCmd = &cobra.Command{
	Use:   "update [flags]",
	Short: `Unregister a tool.`,
	Long: `Updates a Githooks Readme in the '.githooks' folder.
It overwrite the file if it exists already.`,
	Run: runUpdateReadme}

func updateReadme(panicIfExists bool) {

	repoDir, _ := assertRepoRoot(&settings)

	file := hooks.GetReadmeFile(repoDir)

	log.PanicIfF(panicIfExists && cm.IsFile(file),
		"This repository already seems to have a Githooks README.\n"+
			"To replace it with the latest one, please run\n"+
			"'git hooks readme update'.")

	err := hooks.WriteReadmeFile(file)
	log.AssertNoErrorPanicF(err, "Could not write README file '%s'.", file)

	relFile, err := filepath.Rel(settings.Cwd, file)
	if err != nil {
		relFile = file
	}
	log.InfoF("The README file '%s' is updated.", relFile)

	if !settings.GitX.IsBareRepo() {
		log.Info("Do not forget to commit and push it!")
	}
}

func runAddReadme(cmd *cobra.Command, args []string) {
	updateReadme(true)
}

func runUpdateReadme(cmd *cobra.Command, args []string) {
	updateReadme(false)
}

func init() { // nolint: gochecknoinits
	readmeCmd.AddCommand(setCommandDefaults(updateReadmeCmd))
	readmeCmd.AddCommand(setCommandDefaults(addReadmeCmd))
	rootCmd.AddCommand(setCommandDefaults(readmeCmd))
}
