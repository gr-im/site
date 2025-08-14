(lang dune 3.10)

(name site)
(generate_opam_files)
(opam_file_location inside_opam_directory)
(executables_implicit_empty_intf)
(using mdx 0.4)

(source (github gr-im/site))
(license GPL-3.0-or-later)
(authors "Pierre d. M. d'A. <grimfw@gmail.com>")
(maintainers "Pierre d. M. d'A. <grimfw@gmail.com>")

(package
  (name site)
  (synopsis "My personal website")
  (description "Source code of the generator of my personal website")
  (depends
    (ocaml (>= 5.3.0))
    (mdx (>= 2.4.1))
    (cmdliner (>= 1.0.0))
    yocaml
    yocaml_unix
    yocaml_yaml
    yocaml_jingoo
    yocaml_syndication
    yocaml_cmarkit

    (ocamlformat :with-dev-setup)
    (ocp-indent :with-dev-setup)
    (merlin :with-dev-setup)
    (ocaml-lsp-server :with-dev-setup)
    (utop :with-dev-setup)))
