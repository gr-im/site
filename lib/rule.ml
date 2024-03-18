open Yocaml

let watch_binary = Build.watch Sys.argv.(0)

let css ~target =
  let open Build in
  let target = Resolver.css ~target in
  create_file target (read_file "css/reset.css" >>> pipe_content "css/style.css")

let pages ~target =
  let open Build in
  process_files [ "pages" ] (Filepath.with_extension "md") (fun file ->
      let target = Resolver.page ~target file in
      create_file target
        (watch_binary
        >>> Yocaml_yaml.read_file_with_metadata (module Repr.Page) file
        >>> snd @@ Markdown.to_html ~strict:false
        >>> Yocaml_jingoo.apply_as_template
              (module Repr.Page)
              "templates/main.html"
        >>^ Stdlib.snd))

let articles ~target =
  let open Build in
  let apply_as_template =
    Yocaml_jingoo.apply_as_template (module Repr.Article)
  in
  process_files [ "articles" ] (Filepath.with_extension "md") (fun file ->
      let target = Resolver.article ~target file in
      create_file target
        (watch_binary
        >>> Yocaml_yaml.read_file_with_metadata (module Repr.Article) file
        >>> Repr.Article.prepare
        >>> snd @@ Markdown.to_html ~strict:false
        >>> apply_as_template "templates/article.html"
        >>> apply_as_template "templates/main.html"
        >>^ Stdlib.snd))

let index ~target =
  let open Build in
  let apply_as_template =
    Yocaml_jingoo.apply_as_template (module Repr.Articles)
  in
  let* articles = Repr.Articles.all (module Yocaml_yaml) in
  create_file
    ("index.html" |> into target)
    (watch_binary
    >>> Yocaml_yaml.read_file_with_metadata (module Repr.Articles) "index.md"
    >>> articles
    >>> snd @@ Markdown.to_html ~strict:false
    >>> apply_as_template "templates/articles.html"
    >>> apply_as_template "templates/main.html"
    >>^ Stdlib.snd)

let all ~target =
  let* () = css ~target in
  let* () = pages ~target in
  let* () = articles ~target in
  index ~target
