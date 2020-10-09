package hooks

import (
	"io/ioutil"
	"path/filepath"
	cm "rycus86/githooks/common"
	strs "rycus86/githooks/strings"
	"strings"
)

// IsRepoTrusted tells if the repository `repoPath` is trusted.
// On any error `false` is reported together with the error.
func IsRepoTrusted(
	git *cm.GitContext,
	installDir string,
	repoPath string,
	promptUser bool) (bool, error) {

	trustFile := filepath.Join(repoPath, ".githooks", "trust-all")
	var err error
	var isTrusted bool = false

	if cm.PathExists(trustFile) {
		trustFlag := git.GetConfig("githooks.trust.all", cm.LocalScope)

		if trustFlag == "" && promptUser {
			question := "This repository wants you to trust all current and\n" +
				"future hooks without prompting.\n" +
				"Do you want to allow running every current and future hooks?"

			answer, err := ShowPrompt(git, installDir, question, "(yes, No)", "y/N", "Yes", "No")

			if err == nil {
				if answer == "y" || answer == "Y" {
					err = git.SetConfig("githooks.trust.all", true, cm.LocalScope)
					if err == nil {
						isTrusted = true
					}
				} else {
					err = git.SetConfig("githooks.trust.all", false, cm.LocalScope)
				}
			}

		} else if trustFlag == "true" || trustFlag == "y" || trustFlag == "Y" {
			isTrusted = true
		}
	}

	return isTrusted, err
}

// ChecksumData represents the data for one checksum which was stored.
type ChecksumData struct {
	HookPath string
}

// ChecksumStore represents a set of checksum which
// can be consulted to check if a hook is trusted or not.
type ChecksumStore struct {
	// checksumDirs are the paths to the checksum directories as (.git/objects)
	checksumDirs []string

	// checksums are the values from checksum files (if existing)
	checksums map[string]ChecksumData
}

// NewChecksumStore creates a checksum store from `path` (file or directory).
func NewChecksumStore(path string, errorIfNotExists bool) (ChecksumStore, error) {
	c := ChecksumStore{}
	err := c.Add(path, errorIfNotExists)
	return c, err
}

// Add adds checksum data from `path` (file or directory) to the store.
func (t *ChecksumStore) Add(path string, errorIfNotExists bool) error {

	if cm.IsFile(path) {

		content, err := ioutil.ReadFile(path)

		if err != nil {
			return cm.ErrorF("Could not read checksum file '%s'", path)
		}

		if t.checksums == nil {
			t.checksums = make(map[string]ChecksumData)
		}

		for idx, l := range strs.SplitLines(string(content)) {
			l := strings.TrimSpace(l)
			if l == "" {
				continue
			}

			pathAndHash := strings.SplitN(strings.TrimSpace(l), " ", 2)
			if len(pathAndHash) != 2 {
				return cm.ErrorF("Could not parse checksum file '%s:%v: '%q'", path, idx+1, pathAndHash)
			}

			t.checksums[pathAndHash[0]] = ChecksumData{strings.TrimSpace(pathAndHash[1])}
		}

	} else if cm.IsDirectory(path) {

		t.checksumDirs = append(t.checksumDirs, path)

	} else if errorIfNotExists {

		return cm.ErrorF("Path '%s' does not exist", path)
	}
	return nil
}

// IsTrusted checks if a path has been trusted.
func (t *ChecksumStore) IsTrusted(path string) (bool, error) {

	sha1, err := cm.GetSHA1Hash(path)

	if err != nil {
		return false, cm.ErrorF("Could not get hash for '%s'", path)
	}

	// Check first all directories ...
	for _, dir := range t.checksumDirs {
		if cm.PathExists(filepath.Join(dir, sha1)) {
			return true, nil
		}
	}

	// Check all checksums ...
	_, ok := t.checksums[sha1]
	if ok {
		return true, nil
	}

	return false, nil
}

// Summary returns a summary of the checksum store.
func (t *ChecksumStore) Summary() string {
	return strs.Fmt("Checksum store contains '%v' parsed checksums and '%v' search paths.", len(t.checksums), len(t.checksumDirs))
}
