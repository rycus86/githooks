// +build tools

package main

import (
	"path"
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"

	"github.com/go-bindata/go-bindata"
)

var pkg = "build"
var embeddedFile = "build/embedded-files.go"

func main() {

	root, err := git.Ctx().Get("rev-parse", "--show-toplevel")
	cm.AssertNoErrorPanicF(err, "Could not root dir.")

	srcRoot := path.Join(root, "githooks")

	template := path.Join(root, "base-template-wrapper.sh")
	readme := path.Join(root, ".githooks", "README.md")

	c := bindata.Config{
		Input: []bindata.InputConfig{
			{Path: template, Recursive: false},
			{Path: readme, Recursive: false}},
		Package:        pkg,
		NoMemCopy:      false,
		NoCompress:     false,
		HttpFileSystem: false,
		Debug:          false,
		Prefix:         root,
		Output:         path.Join(srcRoot, embeddedFile)}

	err = bindata.Translate(&c)

	cm.AssertNoErrorPanicF(err,
		"Translating file '%s' into embedded binary failed.", template)
}
