// +build !mock

package updates

// DefaultURL is the default remote url for release clones.
var defaultURL = "https://github.com/gabyx/githooks.git"

// DefaultBranch is the default branch for release clones.
// Empty means we clone the default branch.
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
