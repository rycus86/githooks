package common

import (
	"encoding/json"
	"io/ioutil"
	"os"
	strs "rycus86/githooks/strings"
)

// RegisterRepos is the format of the register file
// in the install folder.
type RegisterRepos struct {
	GitDirs []string
}

// GetRegisteredRepos gets the registered repos from a file
func GetRegisteredRepos(file string) (RegisterRepos, error) {
	var repos RegisterRepos

	if PathExists(file) {

		jsonFile, err := os.Open(file)
		if err != nil {
			return repos, err
		}
		defer jsonFile.Close()

		bytes, err := ioutil.ReadAll(jsonFile)
		if err != nil {
			return repos, err
		}

		if err := json.Unmarshal(bytes, &repos); err != nil {
			return repos, err
		}
	}

	return repos, nil
}

// SetRegisteredRepos gets the registered repos from a file
func SetRegisteredRepos(repos RegisterRepos, file string) error {

	jsonFile, err := os.OpenFile(file, os.O_RDWR|os.O_CREATE, 0755)
	if err != nil {
		return err
	}
	defer jsonFile.Close()

	bytes, err := json.Marshal(repos)
	if err != nil {
		return err
	}

	if _, err := jsonFile.Write(bytes); err != nil {
		return err
	}
	return nil
}

// Insert adds a repository Git directory uniquely
func (r *RegisterRepos) Insert(gitDir string) {
	r.GitDirs = strs.AppendUnique(r.GitDirs, gitDir)
}

// Remove removes a repository Git directory
func (r *RegisterRepos) Remove(gitDir string) {
	r.GitDirs = strs.Remove(r.GitDirs, gitDir)
}
