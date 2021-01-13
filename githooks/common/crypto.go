package common

import (
	"bytes"
	"errors"
	"fmt"
	"io"

	"golang.org/x/crypto/openpgp/armor"
	"golang.org/x/crypto/openpgp/packet"
)

// VerifyFile verifies an input `file` with its `signature`
// provided a public GPG kex in hex format.
func VerifyFile(file io.Reader, signature io.Reader, publicKey string) error {

	// Read the signature file
	pack, err := packet.Read(signature)
	if err != nil {
		return err
	}

	// Was it really a signature file ? If yes, get the Signature
	sig, ok := pack.(*packet.Signature)
	if !ok {
		return ErrorF("Not a GPG signature.")
	}

	// Decode armored public key
	block, err := armor.Decode(bytes.NewReader([]byte(publicKey)))
	if err != nil {
		return fmt.Errorf("error decoding public key: %s", err)
	}
	if block.Type != "PGP PUBLIC KEY BLOCK" {
		return errors.New("not an armored public key")
	}

	// Read the key
	pack, err = packet.Read(block.Body)
	if err != nil {
		return CombineErrors(err, Error("Could not read the key."))
	}

	// Was it really a public key file ? If yes, get the PublicKey
	key, ok := pack.(*packet.PublicKey)
	if !ok {
		return Error("Invalid public key.")
	}

	// Get the hash method used for the signature
	hash := sig.Hash.New()

	// Hash the content of the file
	buf := make([]byte, 1024)
	for {
		n, err := file.Read(buf)
		if err == io.EOF {
			break
		}

		_, err = hash.Write(buf[:n])
		if err != nil {
			return CombineErrors(err, Error("Failed hashing the file."))
		}
	}

	// Check the signature
	err = key.VerifySignature(hash, sig)
	if err != nil {
		return CombineErrors(err, Error("Signature verification failed."))
	}

	return nil
}
