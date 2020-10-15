package common

import (
	"crypto/sha1"
	"encoding/hex"
	"io"
	"os"
)

// GetSHA1HashFile gets the SHA1 hash of a file.
func GetSHA1HashFile(path string) (string, error) {
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

// GetSHA1HashString gets the SHA1 hash of a string.
func GetSHA1HashString(s string) string {
	h := sha1.New()
	h.Write([]byte(s))
	return hex.EncodeToString(h.Sum(nil))
}
