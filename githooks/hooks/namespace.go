package hooks

import (
	"io/ioutil"
	"path"
	cm "rycus86/githooks/common"
	"strings"
)

const (
	ReplacedHookNamespace = "hooks"
)

func getNamespaceFile(hooksDir string) string {
	return path.Join(hooksDir, ".namespace")
}

// GetHooksNamespace get the namespace in which
// all hooks in `hooksDir` are residing.
func GetHooksNamespace(hookDir string) (s string, err error) {
	f := getNamespaceFile(hookDir)
	if cm.IsFile(f) {
		var data []byte
		data, err = ioutil.ReadFile(f)
		s = strings.TrimSpace(string(data))
	}

	return
}
