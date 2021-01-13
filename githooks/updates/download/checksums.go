package download

import (
	"bytes"
	"io/ioutil"
	"os"
	cm "rycus86/githooks/common"
	"strings"
)

// verifyChecksums verifies checksums with the signature and the public key, and returns
// the checksums content.
func verifyChecksums(checksums Checksums, publicPGP string) ([]byte, error) {

	checksumFile, err := DownloadFile(checksums.File.Url)
	if err != nil {
		return nil, err
	}
	defer checksumFile.Body.Close()

	checksumFileSignature, err := DownloadFile(checksums.FileSignature.Url)
	if err != nil {
		return nil, err
	}
	defer checksumFileSignature.Body.Close()

	// Read the checksumFile into memory
	checksumBytes, err := ioutil.ReadAll(checksumFile.Body)
	if err != nil {
		return nil, err
	}

	err = cm.VerifyFile(bytes.NewReader(checksumBytes), checksumFileSignature.Body, publicPGP)
	if err != nil {
		return nil, err
	}

	return checksumBytes, nil
}

// checkChecksum checks if the checksum of file matches the checksum.
func checkChecksum(filePath string, checksumData []byte) (err error) {
	var file *os.File

	file, err = os.Open(filePath)
	if err != nil {
		return
	}
	defer file.Close()

	hash, err := cm.GetSHA256Hash(file)
	if err != nil {
		return err
	}

	if !strings.Contains(string(checksumData), hash) {
		return cm.ErrorF("Could not find checksum '%s' in checksum data.", filePath)
	}

	return nil
}
