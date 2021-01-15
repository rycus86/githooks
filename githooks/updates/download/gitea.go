package download

import (
	"io"
	"os"
	"path"
	cm "rycus86/githooks/common"

	"code.gitea.io/sdk/gitea"
)

// The deploy settings for Gitea.
type GiteaDeploySettings struct {
	GithubDeploySettings
	GiteaURL string // Base url of the Gitea service.
}

// Providing interface `IDeploySettings`.
func (s *GiteaDeploySettings) Download(versionTag string, dir string) error {
	return downloadGitea(s.GiteaURL, s.Owner, s.Repository, versionTag, dir, s.PublicPGP)
}

// Downloads the Githooks release with tag `versionTag` and
// extracts the matched asset into `dir`.
// The assert matches the OS and architecture of the current runtime.
func downloadGitea(url string, owner string, repo string, versionTag string, dir string, publicPGP string) error {

	client, err := gitea.NewClient(url)
	if err != nil {
		return cm.CombineErrors(err, cm.Error("Cannot initialize Gitea client"))
	}

	rel, _, err := client.GetReleaseByTag(owner, repo, versionTag)
	if err != nil {
		return cm.CombineErrors(err, cm.Error("Failed to get release"))
	}

	// Wrap into our list
	var assets []Asset
	for i := range rel.Attachments {
		assets = append(assets,
			Asset{
				FileName: path.Base(rel.Attachments[i].Name),
				Url:      rel.Attachments[i].DownloadURL})
	}

	target, checksums, err := getGithooksAsset(assets)
	if err != nil {
		return cm.CombineErrors(err,
			cm.ErrorF("Could not select asset in repo '%s/%s' at tag '%s'.", owner, repo, versionTag))
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

	err = Extract(tempFile, target.Extension, dir)
	if err != nil {
		return cm.CombineErrors(err,
			cm.ErrorF("Assert extractiuon from url '%s' failed.", url))
	}

	return nil
}
