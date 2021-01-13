package download

import (
	"net/http"
	cm "rycus86/githooks/common"
)

// DownloadFile downloads a file from a `url`.
// Response body needs to be closed by caller.
func DownloadFile(url string) (response *http.Response, err error) {
	// Get the response bytes from the url
	response, err = http.Get(url)
	if err != nil {
		return
	}

	if response.StatusCode != http.StatusOK {
		return nil, cm.ErrorF("Download of '%s' failed with status: '%v'.",
			url, response.StatusCode)
	}

	return
}
