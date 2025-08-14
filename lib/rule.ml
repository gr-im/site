open Yocaml

let track_binary = Pipeline.track_file (Path.rel [ Sys.argv.(0) ])

let css ~target =
  let target = Resolver.css ~target in
  Action.Static.write_file target
  @@ Pipeline.pipe_files ~separator:"\n"
       Path.[ rel [ "css"; "reset.css" ]; rel [ "css"; "style.css" ] ]

let page ~target file =
  let target = Resolver.page ~target file in
  Action.Static.write_file_with_metadata target
    (let open Task in
     track_binary
     >>> Yocaml_yaml.Pipeline.read_file_with_metadata (module Repr.Page) file
     >>> Yocaml_cmarkit.content_to_html ()
     >>> Yocaml_jingoo.Pipeline.as_template
           (module Repr.Page)
           (Path.rel [ "templates"; "main.html" ]))

let article ~target file =
  let target = Resolver.article ~target file in
  Action.Static.write_file_with_metadata target
    (let open Task in
     track_binary
     >>> Yocaml_yaml.Pipeline.read_file_with_metadata (module Repr.Article) file
     >>> Repr.Article.prepare
     >>> Yocaml_cmarkit.content_to_html ()
     >>> Yocaml_jingoo.Pipeline.as_template
           (module Repr.Article)
           (Path.rel [ "templates"; "article.html" ])
     >>> Yocaml_jingoo.Pipeline.as_template
           (module Repr.Article)
           (Path.rel [ "templates"; "main.html" ]))

let pages ~target =
  Action.batch ~only:`Files ~where:(Path.has_extension "md")
    (Path.rel [ "pages" ]) (page ~target)

let articles ~target =
  Action.batch ~only:`Files ~where:(Path.has_extension "md")
    (Path.rel [ "articles" ]) (article ~target)

let atom ~target =
  let articles = Path.rel [ "articles" ] in
  Action.Static.write_file
    Path.(target / "atom.xml")
    (let open Task in
     Pipeline.track_file articles
     >>> Repr.Articles.to_atom (Path.rel [ "articles" ]))

let index ~target =
  let articles = Path.rel [ "articles" ] in
  Action.Static.write_file_with_metadata
    Path.(target / "index.html")
    (let open Task in
     track_binary
     >>> Pipeline.track_file articles
     >>> Yocaml_yaml.Pipeline.read_file_with_metadata
           (module Repr.Page)
           (Path.rel [ "index.md" ])
     >>> first (Repr.Articles.index articles)
     >>> Yocaml_cmarkit.content_to_html ()
     >>> Yocaml_jingoo.Pipeline.as_template
           (module Repr.Articles)
           (Path.rel [ "templates"; "articles.html" ])
     >>> Yocaml_jingoo.Pipeline.as_template
           (module Repr.Articles)
           (Path.rel [ "templates"; "main.html" ]))

let all ~target () =
  let open Eff in
  let cache = Path.(target / "cache") in
  Action.restore_cache cache
  >>= css ~target
  >>= pages ~target
  >>= articles ~target
  >>= index ~target
  >>= atom ~target
  >>= Action.store_cache cache
