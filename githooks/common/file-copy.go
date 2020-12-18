package common

import (
	"io"
	"os"
)

// CopyFile copies the contents of the file named src to the file named
// by dst. The file will be created if it does not already exist. If the
// destination file exists, all it's contents will be replaced by the contents
// of the source file.
func CopyFile(src string, dst string) (err error) {
	in, err := os.Open(src)
	if err != nil {
		return
	}
	defer in.Close()

	out, err := os.Create(dst)
	if err != nil {
		return
	}

	defer func() {
		cerr := out.Close()
		err = CombineErrors(err, cerr)
	}()

	if _, err = io.Copy(out, in); err != nil {
		return
	}

	err = out.Sync()
	return
}
