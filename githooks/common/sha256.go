package common

import (
	"crypto/sha256"
	"encoding/hex"
	"io"
)

// GetSHA256Hash gets the SHA1 hash of a string.
func GetSHA256Hash(reader io.Reader) (string, error) {
	h := sha256.New()
	if _, err := io.Copy(h, reader); err != nil {
		return "", err
	}

	return hex.EncodeToString(h.Sum(nil)), nil
}
