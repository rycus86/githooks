package common

import (
	"io/ioutil"
	"os"

	"github.com/goccy/go-yaml"
)

// LoadYAML loads and parses JSON file into a representation.
func LoadYAML(file string, repr interface{}) error {
	yamlFile, err := os.Open(file)
	if err != nil {
		return ErrorF("Could not open file '%s'.", file)
	}
	defer yamlFile.Close()

	bytes, err := ioutil.ReadAll(yamlFile)
	if err != nil {
		return ErrorF("Could not read file '%s'.", file)
	}

	if err := yaml.Unmarshal(bytes, repr); err != nil {
		return ErrorF("Could not parse file '%s'.", file)
	}
	return nil
}

// StoreYAML stores a representation in a JSON file.
func StoreYAML(file string, repr interface{}) error {
	yamlFile, err := os.OpenFile(file, os.O_WRONLY|os.O_TRUNC|os.O_CREATE, 0664)
	if err != nil {
		return err
	}
	defer yamlFile.Close()

	bytes, err := yaml.Marshal(repr)
	if err != nil {
		return err
	}

	if _, err := yamlFile.Write(bytes); err != nil {
		return err
	}
	return nil
}
