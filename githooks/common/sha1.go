package common

import (
	"crypto/sha1"
	"encoding/hex"
	"io"
	"os"
)

// GetSha1Hash gets the SHA1 hash of a file.
func GetSHA1Hash(path string) (string, error) {
	file, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer file.Close()

	// Open a new SHA1 hash interface to write to
	hash := sha1.New()

	// Copy the file in the hash interface and check for any error
	if _, err := io.Copy(hash, file); err != nil {
		return "", err
	}

	return hex.EncodeToString(hash.Sum(nil)), nil
}
