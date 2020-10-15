package git

// IsBareRepo returns if `path` is a bare repository.
func IsBareRepo(path string) bool {
	out, _ := CtxC(path).Get("rev-parse", "--is-bare-repository")
	return out == "true"
}
