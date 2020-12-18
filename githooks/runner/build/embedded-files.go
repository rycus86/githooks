// Code generated for package build by go-bindata DO NOT EDIT. (@generated)
// sources:
// ../../base-template-wrapper.sh
package build

import (
	"bytes"
	"compress/gzip"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"
	"time"
)

func bindataRead(data []byte, name string) ([]byte, error) {
	gz, err := gzip.NewReader(bytes.NewBuffer(data))
	if err != nil {
		return nil, fmt.Errorf("Read %q: %v", name, err)
	}

	var buf bytes.Buffer
	_, err = io.Copy(&buf, gz)
	clErr := gz.Close()

	if err != nil {
		return nil, fmt.Errorf("Read %q: %v", name, err)
	}
	if clErr != nil {
		return nil, err
	}

	return buf.Bytes(), nil
}

type asset struct {
	bytes []byte
	info  os.FileInfo
}

type bindataFileInfo struct {
	name    string
	size    int64
	mode    os.FileMode
	modTime time.Time
}

// Name return file name
func (fi bindataFileInfo) Name() string {
	return fi.name
}

// Size return file size
func (fi bindataFileInfo) Size() int64 {
	return fi.size
}

// Mode return file mode
func (fi bindataFileInfo) Mode() os.FileMode {
	return fi.mode
}

// Mode return file modify time
func (fi bindataFileInfo) ModTime() time.Time {
	return fi.modTime
}

// IsDir return file whether a directory
func (fi bindataFileInfo) IsDir() bool {
	return fi.mode&os.ModeDir != 0
}

// Sys return file is sys mode
func (fi bindataFileInfo) Sys() interface{} {
	return nil
}

var _homeGabyxDesktopRepositoryGithooksBaseTemplateWrapperSh = []byte("\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\xff\x6c\x91\x41\x6f\xd4\x30\x10\x85\xef\xfe\x15\x6f\x93\x15\x82\x43\x13\xe0\x80\x10\x08\x84\x90\x50\xa9\x90\x5a\xb4\xc0\x89\x22\xea\x4d\x27\xc9\x50\xaf\x27\xf2\x4c\x4a\xf6\xdf\x23\x27\xbb\xa8\x6a\x7b\xf1\x61\xfc\xfc\xde\x37\xcf\xe5\xaa\xde\x72\xac\xb5\x77\x25\x3e\x7a\x25\x9c\xb2\xa1\x17\xb9\x81\xd1\x6e\x08\xde\x08\x6d\x92\x1d\x7a\xb3\x41\xdf\xd4\x75\xc7\xd6\x8f\xdb\xaa\x91\x5d\x9d\xf6\xcd\xa8\xaf\x5f\xcd\x23\x91\x1b\x75\xa5\x2b\x71\x66\xf0\x21\xc8\x5f\xc5\x5e\x46\x98\xa0\xf7\xb7\x04\x8f\xea\xa8\x42\x2b\xe1\x9a\x12\x06\x4a\x27\x43\x92\x3f\xd4\x18\xac\xf7\x86\x46\xa2\x79\x8e\xea\x4a\xb0\x29\x16\xb1\x09\x68\xa2\x66\x34\x82\x44\xdc\xfa\xc4\x32\xea\xcc\x68\x89\xbb\x8e\x92\x56\xce\x95\xd8\x90\xbf\x86\xf5\x84\x34\xc6\x48\x09\xda\x24\x1e\x6c\x21\xcf\xe3\x20\x8d\x0f\x75\x17\x64\xeb\x03\x24\x41\xf7\x6a\xb4\xcb\x91\x2d\x77\xee\xf4\xec\xfb\xe7\x8b\x8b\x2f\xdf\x7e\x6f\x7e\x9c\x9f\x7f\xda\xbc\x5b\x3f\xed\xd8\x0e\x97\x38\x72\x57\x8b\xf5\x33\xe7\xb8\xc5\x4f\xac\x70\x32\xa1\x58\xdf\x7b\x5a\xe0\xd7\xdb\x1c\x18\x1d\x00\x50\xd3\x0b\x8a\x55\xc6\x5d\xb6\x39\xd0\x0d\xc2\xd1\xe6\xdd\x3c\xa2\x44\xd0\xc4\x6a\x1c\xbb\x19\xd3\x58\x62\x81\xf7\x4f\x5e\xde\xb1\x00\x70\x79\x75\x3f\xeb\xf2\xea\x81\x4c\x12\xd8\xc0\x8a\x28\x76\xe8\xcd\x6f\x03\xad\x1e\x08\xbf\x06\xca\x7f\x9d\xc6\x38\xd7\xf3\x1f\x90\xa3\x9a\x0f\xe1\xd8\x9f\xef\x3c\xc7\xcc\xd9\xf2\x04\xb6\xea\x8e\xcf\xc4\x86\x17\xae\x65\xe7\x72\xce\x63\x4d\x14\xeb\xe7\xf9\xf8\x50\xb8\x7f\x01\x00\x00\xff\xff\xa0\x82\x3d\x00\x64\x02\x00\x00")

func homeGabyxDesktopRepositoryGithooksBaseTemplateWrapperShBytes() ([]byte, error) {
	return bindataRead(
		_homeGabyxDesktopRepositoryGithooksBaseTemplateWrapperSh,
		"home/gabyx/Desktop/Repository/githooks/base-template-wrapper.sh",
	)
}

func homeGabyxDesktopRepositoryGithooksBaseTemplateWrapperSh() (*asset, error) {
	bytes, err := homeGabyxDesktopRepositoryGithooksBaseTemplateWrapperShBytes()
	if err != nil {
		return nil, err
	}

	info := bindataFileInfo{name: "home/gabyx/Desktop/Repository/githooks/base-template-wrapper.sh", size: 612, mode: os.FileMode(509), modTime: time.Unix(1608328838, 0)}
	a := &asset{bytes: bytes, info: info}
	return a, nil
}

// Asset loads and returns the asset for the given name.
// It returns an error if the asset could not be found or
// could not be loaded.
func Asset(name string) ([]byte, error) {
	cannonicalName := strings.Replace(name, "\\", "/", -1)
	if f, ok := _bindata[cannonicalName]; ok {
		a, err := f()
		if err != nil {
			return nil, fmt.Errorf("Asset %s can't read by error: %v", name, err)
		}
		return a.bytes, nil
	}
	return nil, fmt.Errorf("Asset %s not found", name)
}

// MustAsset is like Asset but panics when Asset would return an error.
// It simplifies safe initialization of global variables.
func MustAsset(name string) []byte {
	a, err := Asset(name)
	if err != nil {
		panic("asset: Asset(" + name + "): " + err.Error())
	}

	return a
}

// AssetInfo loads and returns the asset info for the given name.
// It returns an error if the asset could not be found or
// could not be loaded.
func AssetInfo(name string) (os.FileInfo, error) {
	cannonicalName := strings.Replace(name, "\\", "/", -1)
	if f, ok := _bindata[cannonicalName]; ok {
		a, err := f()
		if err != nil {
			return nil, fmt.Errorf("AssetInfo %s can't read by error: %v", name, err)
		}
		return a.info, nil
	}
	return nil, fmt.Errorf("AssetInfo %s not found", name)
}

// AssetNames returns the names of the assets.
func AssetNames() []string {
	names := make([]string, 0, len(_bindata))
	for name := range _bindata {
		names = append(names, name)
	}
	return names
}

// _bindata is a table, holding each asset generator, mapped to its name.
var _bindata = map[string]func() (*asset, error){
	"home/gabyx/Desktop/Repository/githooks/base-template-wrapper.sh": homeGabyxDesktopRepositoryGithooksBaseTemplateWrapperSh,
}

// AssetDir returns the file names below a certain
// directory embedded in the file by go-bindata.
// For example if you run go-bindata on data/... and data contains the
// following hierarchy:
//     data/
//       foo.txt
//       img/
//         a.png
//         b.png
// then AssetDir("data") would return []string{"foo.txt", "img"}
// AssetDir("data/img") would return []string{"a.png", "b.png"}
// AssetDir("foo.txt") and AssetDir("notexist") would return an error
// AssetDir("") will return []string{"data"}.
func AssetDir(name string) ([]string, error) {
	node := _bintree
	if len(name) != 0 {
		cannonicalName := strings.Replace(name, "\\", "/", -1)
		pathList := strings.Split(cannonicalName, "/")
		for _, p := range pathList {
			node = node.Children[p]
			if node == nil {
				return nil, fmt.Errorf("Asset %s not found", name)
			}
		}
	}
	if node.Func != nil {
		return nil, fmt.Errorf("Asset %s not found", name)
	}
	rv := make([]string, 0, len(node.Children))
	for childName := range node.Children {
		rv = append(rv, childName)
	}
	return rv, nil
}

type bintree struct {
	Func     func() (*asset, error)
	Children map[string]*bintree
}

var _bintree = &bintree{nil, map[string]*bintree{
	"home": &bintree{nil, map[string]*bintree{
		"gabyx": &bintree{nil, map[string]*bintree{
			"Desktop": &bintree{nil, map[string]*bintree{
				"Repository": &bintree{nil, map[string]*bintree{
					"githooks": &bintree{nil, map[string]*bintree{
						"base-template-wrapper.sh": &bintree{homeGabyxDesktopRepositoryGithooksBaseTemplateWrapperSh, map[string]*bintree{}},
					}},
				}},
			}},
		}},
	}},
}}

// RestoreAsset restores an asset under the given directory
func RestoreAsset(dir, name string) error {
	data, err := Asset(name)
	if err != nil {
		return err
	}
	info, err := AssetInfo(name)
	if err != nil {
		return err
	}
	err = os.MkdirAll(_filePath(dir, filepath.Dir(name)), os.FileMode(0755))
	if err != nil {
		return err
	}
	err = ioutil.WriteFile(_filePath(dir, name), data, info.Mode())
	if err != nil {
		return err
	}
	err = os.Chtimes(_filePath(dir, name), info.ModTime(), info.ModTime())
	if err != nil {
		return err
	}
	return nil
}

// RestoreAssets restores an asset under the given directory recursively
func RestoreAssets(dir, name string) error {
	children, err := AssetDir(name)
	// File
	if err != nil {
		return RestoreAsset(dir, name)
	}
	// Dir
	for _, child := range children {
		err = RestoreAssets(dir, filepath.Join(name, child))
		if err != nil {
			return err
		}
	}
	return nil
}

func _filePath(dir, name string) string {
	cannonicalName := strings.Replace(name, "\\", "/", -1)
	return filepath.Join(append([]string{dir}, strings.Split(cannonicalName, "/")...)...)
}
