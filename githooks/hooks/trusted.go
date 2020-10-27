package hooks

import (
	"io/ioutil"
	"path"
	"path/filepath"
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"
	"rycus86/githooks/prompt"
	strs "rycus86/githooks/strings"
	"strings"
)

// IsRepoTrusted tells if the repository `repoPath` is trusted.
// On any error `false` is reported together with the error.
func IsRepoTrusted(
	gitx *git.Context,
	promptCtx prompt.IContext,
	repoPath string,
	promptUser bool) (bool, error) {

	trustFile := path.Join(repoPath, HookDirName, "trust-all")
	var isTrusted bool = false

	exists, err := cm.IsPathExisting(trustFile)
	if exists {
		trustFlag := gitx.GetConfig("githooks.trust.all", git.LocalScope)

		if trustFlag == "" && promptUser {
			question := "This repository wants you to trust all current and\n" +
				"future hooks without prompting.\n" +
				"Do you want to allow running every current and future hooks?"

			var answer string
			answer, err = promptCtx.ShowPrompt(question, "(yes, No)", "y/N", "Yes", "No")

			if err == nil && answer == "y" || answer == "Y" {
				err = gitx.SetConfig("githooks.trust.all", true, git.LocalScope)
				if err == nil {
					isTrusted = true
				}
			} else {
				err = gitx.SetConfig("githooks.trust.all", false, git.LocalScope)
			}

		} else if trustFlag == "true" || trustFlag == "y" || trustFlag == "Y" {
			isTrusted = true
		}
	}

	return isTrusted, err
}

const (
	// SHA1Length is the string length of a SHA1 hash.
	SHA1Length = 40
)

// ChecksumResult defines the SHA1 hash and the path it was computed with
type ChecksumResult struct {
	SHA1 string
	Path string
}

// ChecksumStore represents a set of checksum which
// can be consulted to check if a hook is trusted or not.
type ChecksumStore struct {
	// checksumDirs are the paths to the checksum directories containing files
	// with file name equal to the checksum.
	checksumDirs []string

	// checksumFiles are paths to files containing a list of checksums.
	checksumFiles []string

	// checksums are the values from checksumFiles (if existing)
	checksums map[string]ChecksumData
}

// ChecksumData represents the data for one checksum which was stored.
type ChecksumData struct {
	Paths []string
}

func newChecksumData(paths ...string) ChecksumData {
	return ChecksumData{paths}
}

// NewChecksumStore creates a checksum store from `path` (file or directory).
func NewChecksumStore(path string, errorIfNotExists bool) (ChecksumStore, error) {
	c := ChecksumStore{}
	err := c.AddChecksums(path, errorIfNotExists)
	return c, err
}

// AddChecksums adds checksum data from `path` (file or directory) to the store.
func (t *ChecksumStore) AddChecksums(path string, errorIfNotExists bool) error {

	if cm.IsFile(path) {

		content, err := ioutil.ReadFile(path)

		if err != nil {
			return cm.ErrorF("Could not read checksum file '%s'", path)
		}

		t.assertData()

		for idx, l := range strs.SplitLines(string(content)) {
			l := strings.TrimSpace(l)
			if l == "" {
				continue
			}

			pathAndHash := strings.SplitN(strings.TrimSpace(l), " ", 2)
			if len(pathAndHash) < 2 || !filepath.IsAbs(pathAndHash[1]) {
				return cm.ErrorF("Could not parse checksum file '%s:%v: '%q'\nformat: 'sha1<space>absPath'",
					path, idx+1, pathAndHash)
			}
			t.AddChecksum(pathAndHash[0], pathAndHash[1])
		}

		t.checksumFiles = append(t.checksumFiles, path)

	} else if cm.IsDirectory(path) {

		t.checksumDirs = append(t.checksumDirs, path)

	} else if errorIfNotExists {

		return cm.ErrorF("Path '%s' does not exist", path)
	}
	return nil
}

func (t *ChecksumStore) assertData() {
	if t.checksums == nil {
		t.checksums = make(map[string]ChecksumData)
	}
}

// AddChecksum adds a SHA1 checksum of a path and returns if it was added (or merged).
func (t *ChecksumStore) AddChecksum(sha1 string, path string) bool {
	t.assertData()
	path = filepath.ToSlash(path)
	if data, exists := t.checksums[sha1]; exists {
		p := &data.Paths
		*p = append(*p, path)
		return true
	} else {
		t.checksums[sha1] = newChecksumData(path)
		return false
	}
}

// IsTrusted checks if a path has been trusted.
func (t *ChecksumStore) IsTrusted(filePath string) (bool, string, error) {

	sha1, err := git.GetSHA1HashFile(filePath)
	if err != nil {
		return false, sha1,
			cm.CombineErrors(cm.ErrorF("Could not get hash for '%s'", filePath), err)
	}

	// Check first all directories ...
	for _, dir := range t.checksumDirs {
		exists, err := cm.IsPathExisting(path.Join(dir, sha1))
		if exists {
			return true, sha1, nil
		} else if err != nil {
			return false, sha1, err
		}
	}

	// Check all checksums ...
	_, ok := t.checksums[sha1]
	if ok {
		return true, sha1, nil
	}

	return false, sha1, nil
}

// Summary returns a summary of the checksum store.
func (t *ChecksumStore) Summary() string {
	return strs.Fmt(
		"Checksum store contains '%v' parsed checksums from '%v' files\n"+
			"and '%v' directory search paths.",
		len(t.checksums),
		len(t.checksumFiles),
		len(t.checksumDirs))
}
