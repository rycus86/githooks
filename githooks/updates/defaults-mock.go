// +build mock

package updates

import "os"

// DefaultURL is the default remote url for release clones.
var defaultURL = os.Getenv("GITHOOKS_TEST_REPO")

// DefaultBranch is the default branch for release clones.
var defaultBranch = ""

var DefaultRemote = "origin"

// GetDefaultCloneURL get the default clone url.
func GetDefaultCloneURL() string {
	return defaultURL
}

// GetDefaultCloneBranch get the default clone branch.
func GetDefaultCloneBranch() string {
	return defaultBranch
}
