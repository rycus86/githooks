package common

import (
	"archive/tar"
	"compress/gzip"
	"io"
	"os"
	"path"
)

func ExtractTarGz(gzipStream io.Reader, baseDir string) (err error) {
	uncompressedStream, err := gzip.NewReader(gzipStream)
	if err != nil {
		return
	}

	tarReader := tar.NewReader(uncompressedStream)
	var header *tar.Header

	err = os.MkdirAll(baseDir, DefaultFileModeDirectory)
	if err != nil {
		return
	}

	for {
		header, err = tarReader.Next()

		if err == io.EOF {
			break
		} else if err != nil {
			return
		}

		outPath := path.Join(baseDir, header.Name)

		switch header.Typeflag {
		case tar.TypeDir:

			err = os.MkdirAll(outPath, DefaultFileModeDirectory)
			if err != nil {
				return
			}

		case tar.TypeReg:

			var file *os.File
			file, err = os.Create(outPath)
			if err != nil {
				return
			}
			defer file.Close()

			if _, err := io.Copy(file, tarReader); err != nil {
				return CombineErrors(ErrorF("Copy of data to '%s' failed", outPath), err)
			}

			err = file.Chmod(header.FileInfo().Mode())
			if err != nil {
				return
			}

		default:
			return ErrorF("Tar extracting: unknown type: '%v' in '%v'",
				header.Typeflag,
				header.Name)
		}
	}

	return nil
}
