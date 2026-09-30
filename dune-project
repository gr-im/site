(lang dune 3.24)

(name site)
(generate_opam_files)
(executables_implicit_empty_intf)
(using mdx 0.4)

(source (github gr-im/site))
(license GPL-3.0-or-later)
(authors "grm <grimfw@gmail.com>")
(maintainers "grm <grimfw@gmail.com>")

(package
  (name site)
  (synopsis "My personal website")
  (description "Source code of the generator of my personal website")
  (depends
   (ocaml (>= 5.3.0))

   (mdx (>= 2.6.0))
   (cmdliner (>= 1.0.0))
   (cmarkit (>= 0.4.0))
   (hilite (>= 0.5.0))

   (yocaml (>= 3.0.1))
   (yocaml_unix (>= 3.0.1))
   (yocaml_yaml (>= 3.0.1))
   (yocaml_jingoo (>= 3.0.1))
   (yocaml_syndication (>= 3.0.1))
   (yocaml_markdown (>= 3.0.1))

   (ocamlformat :with-dev-setup)
   (ocp-indent :with-dev-setup)
   (merlin :with-dev-setup)
   (ocaml-lsp-server :with-dev-setup)
   (utop :with-dev-setup)))
