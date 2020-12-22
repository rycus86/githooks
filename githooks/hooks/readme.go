package hooks

import (
	"os"
	"path"
	"rycus86/githooks/build"
	cm "rycus86/githooks/common"
)

// GetReadmeFile gets the Githooks readme
// file inside a repository.
func GetReadmeFile(repoHookDir string) string {
	return path.Join(repoHookDir, HookDirName, "README.md")
}

// GetRunWrapperContent gets the bytes of the readme file template.
func getReadmeFileContent() ([]byte, error) {
	return build.Asset(path.Join(HookDirName, "Readme.md"))
}

// WriteReadme writes the readme content to `file`.
func WriteReadmeFile(filePath string) (err error) {
	readmeContent, e := getReadmeFileContent()
	cm.AssertNoErrorPanic(e, "Could not get embedded run wrapper content.")

	file, err := os.Create(filePath)
	if err != nil {
		return
	}
	defer file.Close()

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
