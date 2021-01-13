package download

import (
	"context"
	"io"
	"os"
	"path"
	cm "rycus86/githooks/common"

	"github.com/google/go-github/v33/github"
)

// Downloads the Githooks release with tag `tag` and
// extracts the matched asset it into `dir`.
// The assert matches the OS and architecture of the current runtime.
func DownloadGithub(owner string, repo string, tag string, dir string, publicPGP string) error {

	client := github.NewClient(nil)
	rel, _, err := client.Repositories.GetReleaseByTag(context.Background(),
		"gabyx", "githooks", tag)
	if err != nil {
		return cm.CombineErrors(err, cm.Error("Failed to get release"))
	}

	// Wrap into our list
	var assets []Asset
	for i := range rel.Assets {
		assets = append(assets,
			Asset{
				FileName: path.Base(rel.Assets[i].GetName()),
				Url:      rel.Assets[i].GetBrowserDownloadURL()})
	}

	target, checksums, err := getGithooksAsset(assets)
	if err != nil {
		return cm.CombineErrors(err,
			cm.ErrorF("Could not select asset in repo '%s/%s' at tag '%s'.", owner, repo, tag))
	}

	checksumData, err := verifyChecksums(checksums, publicPGP)
	if err != nil {
		return cm.CombineErrors(err,
			cm.ErrorF("Signature verification of update failed."+
				"Something is fishy!"))
	}

	response, err := DownloadFile(target.Url)
	if err != nil {
		return cm.CombineErrors(err, cm.ErrorF("Could not download url '%s'.", target.Url))
	}
	defer response.Body.Close()

	// Store into temp. file.
	err = os.MkdirAll(dir, cm.DefaultFileModeDirectory)
	if err != nil {
		return cm.ErrorF("Could create dir '%s'.", dir)
	}

	tempFile := cm.GetTempPath(dir, target.FileName)
	temp, err := os.Create(tempFile)
	if err != nil {
		return cm.ErrorF("Could open temp file '%s' for download.", tempFile)
	}
	_, err = io.Copy(temp, response.Body)
	if err != nil {
		return cm.CombineErrors(err, cm.ErrorF("Could not store download in '%s'.", tempFile))
	}

	// Validate checksum.
	err = checkChecksum(tempFile, checksumData)
	if err != nil {
		return cm.CombineErrors(err, cm.ErrorF("Checksum validation failed."))
	}

	// Extract the file.
	f, err := os.Open(tempFile)
	if err != nil {
		return cm.CombineErrors(err, cm.ErrorF("Could not open file '%s'.", tempFile))
	}
	defer f.Close()

	if target.Extension == ".tar.gz" {
		err = cm.ExtractTarGz(f, dir)
	} else {
		cm.Panic("Not implemented")
	}

	if err != nil {
		return cm.CombineErrors(err, cm.ErrorF(
			"Could not extract downloaded file from url\n'%s'\nto '%s'.", target.Url, dir))
	}

	return nil
}
