# https://pkg.go.dev/cmd/go#hdr-Environment_variables
set -xg GOPATH $HOME/Development/frameworks/go
set -xg GOBIN $GOPATH/bin
set -xg GOMODCACHE $GOPATH/pkg/mod

fish_add_path $GOBIN
