package download

import (
	"regexp"
	"runtime"
	cm "rycus86/githooks/common"
)

type githookAssets struct {
	Name string
	Url  string
}

var githooksAssertRe = regexp.MustCompile(`githooks-.*\.(?P<platform>\w+)\.(?P<arch>\w+)(?P<ext>\.zip|\.tar\.gz)`)

func getGithooksAsset(assets []githookAssets) (string, string, error) {

	targetOs := runtime.GOOS
	if targetOs == "darwin" {
		targetOs = "macos"
	}

	targetArch := runtime.GOARCH

	for i := range assets {
		res := githooksAssertRe.FindStringSubmatch(assets[i].Name)

		if len(res) == 0 {
			continue
		}

		os := res[1]
		arch := res[2]
		extension := res[3]

		if targetOs == os && targetArch == arch {
			return assets[i].Url, extension, nil
		}
	}

	return "", "", cm.ErrorF("Could not find any asset for os: '%s' and arch: '%s'.",
		targetOs, targetArch)
}
