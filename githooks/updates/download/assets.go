package download

import (
	"regexp"
	"runtime"
	cm "rycus86/githooks/common"
	strs "rycus86/githooks/strings"
)

type Asset struct {
	FileName string // The file name of the asset.
	Url      string // The download URL of the asset.

	Extension string // Extension of the assert (can be empty).
}

type Checksums struct {
	File          Asset
	FileSignature Asset
}

// IsValid checks if the asset is valid.
func (a *Asset) IsValid() bool {
	return strs.IsNotEmpty(a.FileName) && strs.IsNotEmpty(a.Url)
}

// IsValid checks if the checksums data is valid.
func (c *Checksums) IsValid() bool {
	return c.File.IsValid() && c.FileSignature.IsValid()
}

var githooksBuildAssetRe = regexp.MustCompile(`githooks-.*-(?P<platform>\w+)\.(?P<arch>\w+)(?P<ext>\..*)`)

const githooksChecksumFile = "githooks.checksums"
const githooksChecksumSignatureFile = "githooks.checksums.sig"

// getGithooksAsset returns the correct Githooks asset from the list `assets`.
// The `target.Extension` is also provided.
func getGithooksAsset(assets []Asset) (target Asset, checksums Checksums, err error) {

	targetOs := runtime.GOOS
	if targetOs == "darwin" {
		targetOs = "macos"
	}

	targetArch := runtime.GOARCH

	// Search checksums and its signature.
	for i := range assets {
		if assets[i].FileName == githooksChecksumFile {
			checksums.File = assets[i]
		}

		if assets[i].FileName == githooksChecksumSignatureFile {
			checksums.FileSignature = assets[i]
		}
	}

	if !checksums.IsValid() {
		err = cm.ErrorF("Could not find any checksum and signature file.")

		return
	}

	// Search the asset
	for i := range assets {

		res := githooksBuildAssetRe.FindStringSubmatch(assets[i].FileName)

		if len(res) == 0 {
			continue
		}

		os := res[1]
		arch := res[2]
		ext := res[3]

		if targetOs == os && targetArch == arch {
			target = assets[i]
			target.Extension = ext

			return
		}
	}

	err = cm.ErrorF("Could not find any asset for os: '%s' and arch: '%s'.",
		targetOs, targetArch)

	return
}
