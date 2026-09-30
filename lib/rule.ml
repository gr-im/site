open Yocaml

let track_binary = Pipeline.track_file (Path.from_string Sys.executable_name)

let css resolver =
  let target = Resolver.Target.css resolver in
  Action.Static.write_file target
  @@ Pipeline.pipe_files ~separator:"\n"
  @@ Resolver.Source.css_files resolver

let page resolver file =
  let target = Resolver.Target.page resolver file in
  let pipeline =
    let open Task in
    let+ () = track_binary
    and+ metadata, content =
      Yocaml_yaml.Pipeline.read_file_with_metadata (module Repr.Page) file
    and+ apply_templates =
      Yocaml_jingoo.read_templates
        [ Resolver.Source.template resolver "main.html" ]
    in
    content
    |> Yocaml_markdown.from_string_to_html
    |> apply_templates (module Repr.Page) ~metadata
  in
  Action.Static.write_file target pipeline

let article resolver file =
  let target = Resolver.Target.article resolver file in
  let pipeline =
    let open Task in
    let+ () = track_binary
    and+ metadata, content =
      Yocaml_yaml.Pipeline.read_file_with_metadata (module Repr.Article) file
    and+ apply_templates =
      Yocaml_jingoo.read_templates
        Resolver.Source.
          [ template resolver "article.html"; template resolver "main.html" ]
    in
    let content = Repr.Article.add_footer metadata content in
    content
    |> Yocaml_markdown.from_string_to_html
    |> apply_templates (module Repr.Article) ~metadata
  in
  Action.Static.write_file target pipeline

let pages resolver =
  Action.batch ~only:`Files ~where:(Path.has_extension "md")
    (Resolver.Source.pages resolver)
    (page resolver)

let articles resolver =
  Action.batch ~only:`Files ~where:(Path.has_extension "md")
    (Resolver.Source.articles resolver)
    (article resolver)

let index resolver =
  let target = Resolver.Target.index resolver in
  let articles = Resolver.Source.articles resolver in
  let pipeline =
    let open Task in
    let+ () = track_binary
    and+ articles = Repr.Articles.fetch resolver articles
    and+ page, content =
      Yocaml_yaml.Pipeline.read_file_with_metadata
        (module Repr.Page)
        (Resolver.Source.index resolver)
    and+ apply_templates =
      Yocaml_jingoo.read_templates
        Resolver.Source.
          [ template resolver "articles.html"; template resolver "main.html" ]
    in
    let metadata = Repr.Articles.from_page page articles in
    content
    |> Yocaml_markdown.from_string_to_html
    |> apply_templates (module Repr.Articles) ~metadata
  in
  Action.Static.write_file target pipeline

let atom resolver =
  let articles = Resolver.Source.articles resolver in
  let target = Resolver.Target.atom resolver in
  let pipeline =
    let open Task in
    let+ () = track_binary
    and+ feed = Repr.Articles.to_atom resolver articles in
    Yocaml_syndication.Xml.to_string feed
  in
  Action.Static.write_file target pipeline

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
