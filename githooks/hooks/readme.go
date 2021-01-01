package hooks

import (
	"os"
	"path"
	"rycus86/githooks/build"
	cm "rycus86/githooks/common"
)

// GetReadmeFile gets the Githooks readme
// file inside a repository hooks directory.
func GetReadmeFile(repoDir string) string {
	return path.Join(GetGithooksDir(repoDir), "README.md")
}

// GetRunWrapperContent gets the bytes of the readme file template.
func getReadmeFileContent() ([]byte, error) {
	return build.Asset(path.Join(HooksDirName, "README.md"))
}

// WriteReadme writes the readme content to `file`.
func WriteReadmeFile(filePath string) (err error) {
	readmeContent, e := getReadmeFileContent()
	cm.AssertNoErrorPanic(e, "Could not get embedded readme content.")

	err = os.MkdirAll(path.Dir(filePath), cm.DefaultFileModeDirectory)
	if err != nil {
		return
	}

	file, err := os.Create(filePath)
	if err != nil {
		return
	}
	defer file.Close()

	err = file.Chmod(cm.DefaultFileModeFile)
	if err != nil {
		return
	}

	_, err = file.Write(readmeContent)
	if err != nil {
		return
	}
	err = file.Sync()
	if err != nil {
		return
	}

	return err
}
