# site

> This is the source code for the generator on my personal page (which uses
> [YOCaml](https://github.com/xhtmlboi/yocaml). The aim of this site will be to
> collect notes on the various subjects I deal with, mainly related to
> programming. It will also serve as a repository for older notes that I have
> taken over the years.

## Building locally

This series of instructions explains how to build a local switch, isolated for
development. It assumes you're using [OPAM](https://opam.ocaml.org/) and as the
instructions rely on the existence of the `--with-dev-setup` flag (to install a
development environment), version [`>=
2.2.0+beta1`](https://opam.ocaml.org/blog/opam-2-2-0-beta1/) is required.

```shell
opam update # update the state of opam
opam switch create . --deps-only --with-dev-setup -y
eval $(opam env)
```
