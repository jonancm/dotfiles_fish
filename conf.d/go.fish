# https://pkg.go.dev/cmd/go#hdr-Environment_variables
set -x GOPATH $HOME/Development/frameworks/go
set -x GOBIN $GOPATH/bin
set -x GOMODCACHE $GOPATH/pkg/mod

fish_add_path $GOBIN
