package download

import (
	"net/http"
)

func DownloadFile(url string) (response *http.Response, err error) {
	// Get the response bytes from the url
	response, err = http.Get(url)
	if err != nil {
		return
	}

	if response.StatusCode != 200 { //nolint: gomnd
		return
	}

	return
}
