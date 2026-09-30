open Yocaml

let track_binary = Pipeline.track_file (Path.from_string Sys.argv.(0))

let from_markdown () =
  let open Yocaml.Task in
  Static.on_content
    (Yocaml_cmarkit.to_doc ()
    >>| Hilite_markdown.transform ~skip_unknown_languages:true
    >>> Yocaml_cmarkit.from_doc_to_html ())

let css resolver =
  let target = Resolver.Target.css resolver in
  Action.Static.write_file target
  @@ Pipeline.pipe_files ~separator:"\n"
  @@ Resolver.Source.css_files resolver

let page resolver file =
  let target = Resolver.Target.page resolver file in
  Action.Static.write_file_with_metadata target
    (let open Task in
     track_binary
     >>> Yocaml_yaml.Pipeline.read_file_with_metadata (module Repr.Page) file
     >>> from_markdown ()
     >>> Yocaml_jingoo.Pipeline.as_template
           (module Repr.Page)
           (Resolver.Source.template resolver "main.html"))

let article resolver file =
  let target = Resolver.Target.article resolver file in
  Action.Static.write_file_with_metadata target
    (let open Task in
     track_binary
     >>> Yocaml_yaml.Pipeline.read_file_with_metadata (module Repr.Article) file
     >>> Repr.Article.prepare
     >>> from_markdown ()
     >>> Yocaml_jingoo.Pipeline.as_template
           (module Repr.Article)
           (Resolver.Source.template resolver "article.html")
     >>> Yocaml_jingoo.Pipeline.as_template
           (module Repr.Article)
           (Resolver.Source.template resolver "main.html"))

let pages resolver =
  Action.batch ~only:`Files ~where:(Path.has_extension "md")
    (Resolver.Source.pages resolver)
    (page resolver)

let articles resolver =
  Action.batch ~only:`Files ~where:(Path.has_extension "md")
    (Resolver.Source.articles resolver)
    (article resolver)

let atom resolver =
  let articles = Resolver.Source.articles resolver in
  Action.Static.write_file
    (Resolver.Target.atom resolver)
    (Repr.Articles.to_atom resolver articles)

let index resolver =
  let articles = Resolver.Source.articles resolver in
  Action.Static.write_file_with_metadata
    (Resolver.Target.index resolver)
    (let open Task in
     track_binary
     >>> Pipeline.track_file articles
     >>> Yocaml_yaml.Pipeline.read_file_with_metadata
           (module Repr.Page)
           (Resolver.Source.index resolver)
     >>> first (Repr.Articles.index resolver articles)
     >>> from_markdown ()
     >>> Yocaml_jingoo.Pipeline.as_template
           (module Repr.Articles)
           (Resolver.Source.template resolver "articles.html")
     >>> Yocaml_jingoo.Pipeline.as_template
           (module Repr.Articles)
           (Resolver.Source.template resolver "main.html"))

let all resolver () =
  let open Eff in
  let cache = Resolver.Target.cache resolver in
  Action.restore_cache cache
  >>= css resolver
  >>= pages resolver
  >>= articles resolver
  >>= index resolver
  >>= atom resolver
  >>= Action.remove_residuals ~target:(Resolver.Target.dir resolver)
  >>= Action.store_cache cache
