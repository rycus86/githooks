package download

import (
	"os"
	cm "rycus86/githooks/common"
)

// Exctact extracts a file int dir.
// The extension guides the type of extraction.
func Extract(file string, extension string, dir string) error {
	// Extract the file.
	f, err := os.Open(file)
	if err != nil {
		return cm.CombineErrors(err, cm.ErrorF("Could not open file '%s'.", file))
	}
	defer f.Close()

	if extension == ".tar.gz" {
		err = cm.ExtractTarGz(f, dir)
	} else {
		// @todo  Implement dezip.
		cm.Panic("Not implemented")
	}

	if err != nil {
		return cm.CombineErrors(err, cm.ErrorF(
			"Could not extract downloaded file '%s' into '%s'.", file, dir))
	}

	return nil
}
