package install

import (
	"os"
	"path"
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"
	"rycus86/githooks/hooks"
	strs "rycus86/githooks/strings"
)

func setupReadme(
	log cm.ILogContext,
	repoGitDir string,
	dryRun bool,
	uiSettings *UISettings) {

	mainWorktree, err := git.CtxC(repoGitDir).GetMainWorktree()
	if err != nil || !git.CtxC(mainWorktree).IsGitRepo() {
		log.WarnF("Main worktree could not be determined in:\n'%s'\n"+
			"-> Skipping Readme setup.",
			repoGitDir)

		return
	}

	readme := hooks.GetReadmeFile(mainWorktree)
	hookDir := path.Dir(readme)

	if !cm.IsFile(readme) {

		createFile := false

		switch uiSettings.AnswerSetupIncludedReadme {
		case "s":
			// OK, we already said we want to skip all
			return
		case "a":
			createFile = true
		default:

			var msg string
			if cm.IsDirectory(hookDir) {
				msg = strs.Fmt(
					"Looks like you don't have a '%s' folder in repository\n"+
						"'%s' yet.\n"+
						"Would you like to create one with a 'README'\n"+
						"containing a brief overview of Githooks?", hookDir, mainWorktree)
			} else {
				msg = strs.Fmt(
					"Looks like you don't have a 'README.md' in repository\n"+
						"'%s' yet.\n"+
						"A 'README' file might help contributors\n"+
						"and other team members learn about what is this for.\n"+
						"Would you like to add one now containing a\n"+
						"brief overview of Githooks?", mainWorktree)
			}

			answer, err := uiSettings.PromptCtx.ShowPromptOptions(
				msg, "(Yes, no, all, skip all)",
				"Y/n/a/s",
				"Yes", "No", "All", "Skip All")
			log.AssertNoError(err, "Could not show prompt.")

			switch answer {
			case "s":
				uiSettings.AnswerSetupIncludedReadme = answer
			case "a":
				uiSettings.AnswerSetupIncludedReadme = answer

				fallthrough
			case "y":
				createFile = true
			}
		}

		if createFile {

			if dryRun {
				log.InfoF("[dry run] Readme file '%s' would have been written.", readme)

				return
			}

			err := os.MkdirAll(path.Dir(readme), cm.DefaultFileModeDirectory)

			if err != nil {
				log.WarnF("Could not create directory for '%s'.\n"+
					"-> Skipping Readme setup.", readme)

				return
			}

			err = hooks.WriteReadmeFile(readme)
			log.AssertNoErrorF(err, "Could not write README file '%s'.", readme)
			log.InfoF("Readme file has been written to '%s'.", readme)
		}
	}
}
