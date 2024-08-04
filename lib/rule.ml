open Yocaml

let pipe_content path =
  let open Task in
  lift ~has_dynamic_dependencies:false (fun x -> (x, ()))
  >>> second (Pipeline.read_file path)
  >>> lift ~has_dynamic_dependencies:false (fun (x, y) -> x ^ "\n" ^ y)

let track_binary = Pipeline.track_file (Path.rel [ Sys.argv.(0) ])

let css ~target =
  let target = Resolver.css ~target in
  Action.write_static_file target
    (let open Task in
     Pipeline.read_file (Path.rel [ "css"; "reset.css" ])
     >>> pipe_content (Path.rel [ "css"; "style.css" ]))

let page ~target file =
  let target = Resolver.page ~target file in
  Action.write_static_file target
    (let open Task in
     track_binary
     >>> Yocaml_yaml.Pipeline.read_file_with_metadata (module Repr.Page) file
     >>> Yocaml_omd.content_to_html ()
     >>> Yocaml_jingoo.Pipeline.as_template
           (module Repr.Page)
           (Path.rel [ "templates"; "main.html" ])
     >>> drop_first ())

let article ~target file =
  let target = Resolver.article ~target file in
  Action.write_static_file target
    (let open Task in
     track_binary
     >>> Yocaml_yaml.Pipeline.read_file_with_metadata (module Repr.Article) file
     >>> Repr.Article.prepare
     >>> Yocaml_omd.content_to_html ()
     >>> Yocaml_jingoo.Pipeline.as_template
           (module Repr.Article)
           (Path.rel [ "templates"; "article.html" ])
     >>> Yocaml_jingoo.Pipeline.as_template
           (module Repr.Article)
           (Path.rel [ "templates"; "main.html" ])
     >>> drop_first ())

let pages ~target =
  Action.batch ~only:`Files ~where:(Path.has_extension "md")
    (Path.rel [ "pages" ]) (page ~target)

let articles ~target =
  Action.batch ~only:`Files ~where:(Path.has_extension "md")
    (Path.rel [ "articles" ]) (article ~target)

let index ~target =
  let articles = Path.rel [ "articles" ] in
  Action.write_static_file
    Path.(target / "index.html")
    (let open Task in
     track_binary
     >>> Pipeline.track_file articles
     >>> Yocaml_yaml.Pipeline.read_file_with_metadata
           (module Repr.Page)
           (Path.rel [ "index.md" ])
     >>> first (Repr.Articles.index articles)
     >>> Yocaml_omd.content_to_html ()
     >>> Yocaml_jingoo.Pipeline.as_template
           (module Repr.Articles)
           (Path.rel [ "templates"; "articles.html" ])
     >>> Yocaml_jingoo.Pipeline.as_template
           (module Repr.Articles)
           (Path.rel [ "templates"; "main.html" ])
     >>> drop_first ())

let all ~target () =
  let open Eff in
  let cache = Path.(target / "cache") in
  Action.restore_cache cache
  >>= css ~target
  >>= pages ~target
  >>= articles ~target
  >>= index ~target
  >>= Action.store_cache cache
