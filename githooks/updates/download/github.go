package download

import (
	"context"
	"path"
	cm "rycus86/githooks/common"

	"github.com/google/go-github/v33/github"
)

// Downloads the Githooks release with tag `tag` and
// extracts the matched asset it into `dir`.
// The assert matches the OS and architecture of the current runtime.
func DownloadGithub(owner string, repo string, tag string, dir string) error {

	client := github.NewClient(nil)
	rel, _, err := client.Repositories.GetReleaseByTag(context.Background(), "gabyx", "githooks", tag)
	if err != nil {
		return cm.CombineErrors(err, cm.Error("Failed to get release"))
	}

	var nameAndUrl []githookAssets
	for i := range rel.Assets {
		nameAndUrl = append(nameAndUrl,
			githookAssets{
				Name: path.Base(rel.Assets[i].GetName()),
				Url:  rel.Assets[i].GetBrowserDownloadURL()})
	}

	url, ext, err := getGithooksAsset(nameAndUrl)
	if err != nil {
		return cm.CombineErrors(err,
			cm.ErrorF("Could select asset in url '%s' and tag '%s'.", url, tag))
	}

	response, err := DownloadFile(url)
	if err != nil {
		return cm.CombineErrors(err, cm.ErrorF("Could not download url '%s'.", url))
	}
	defer response.Body.Close()

	if ext == ".tar.gz" {
		err = cm.ExtractTarGz(response.Body, dir)
	} else {
		cm.Panic("Not implemented")
	}

	if err != nil {
		return cm.CombineErrors(err, cm.ErrorF(
			"Could not extract downloaded file from url\n'%s'\nto '%s'.", url, dir))
	}

	return nil
}
