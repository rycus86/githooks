// +build tools

package main

import (
	"path"
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"
	"rycus86/githooks/hooks"

	"github.com/go-bindata/go-bindata"
)

var pkg = "build"
var embeddedFile = "build/embedded-files.go"

func main() {

	root, err := git.Ctx().Get("rev-parse", "--show-toplevel")
	cm.AssertNoErrorPanicF(err, "Could not root dir.")

	githooksRoot := path.Join(root, "githooks")

	template := path.Join(root, "base-template-wrapper.sh")
	readme := hooks.GetReadmeFile(root)

	c := bindata.Config{
		Input: []bindata.InputConfig{
			bindata.InputConfig{Path: template, Recursive: false},
			bindata.InputConfig{Path: readme, Recursive: false}},
		Package:        pkg,
		NoMemCopy:      false,
		NoCompress:     false,
		HttpFileSystem: false,
		Debug:          false,
		Prefix:         root,
		Output:         path.Join(githooksRoot, embeddedFile)}

	err = bindata.Translate(&c)

	cm.AssertNoErrorPanicF(err,
		"Tranlating file '%s' into embedded binary failed.", template)
}
