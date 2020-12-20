package common

import (
	"encoding/json"
	"io/ioutil"
	"os"
)

// LoadJSON loads and parses JSON file into a representation.
func LoadJSON(file string, repr interface{}) error {
	jsonFile, err := os.Open(file)
	if err != nil {
		return ErrorF("Could not open file '%s'.", file)
	}
	defer jsonFile.Close()

	bytes, err := ioutil.ReadAll(jsonFile)
	if err != nil {
		return ErrorF("Could not read file '%s'.", file)
	}

	if err := json.Unmarshal(bytes, repr); err != nil {
		return ErrorF("Could not parse file '%s'.", file)
	}

	return nil
}

// StoreJSON stores a representation in a JSON file.
func StoreJSON(file string, repr interface{}) error {
	jsonFile, err := os.OpenFile(file, os.O_WRONLY|os.O_TRUNC|os.O_CREATE, 0664)
	if err != nil {
		return err
	}
	defer jsonFile.Close()

	bytes, err := json.Marshal(repr)
	if err != nil {
		return err
	}

	if _, err := jsonFile.Write(bytes); err != nil {
		return err
	}

	return nil
}
