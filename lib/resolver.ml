open Yocaml

type t = {
    source : Path.t
  ; target : Path.t
  ; server : Path.t
  ; base_url : string
}

let make ?(source = Path.rel []) ?(target = Path.rel [ "_site" ])
    ?(server = Path.abs []) ~base_url () =
  { source; target; server; base_url }

module Source = struct
  let dir { source; _ } = source
  let css resolver = Path.(dir resolver / "css")
  let templates resolver = Path.(dir resolver / "templates")
  let articles resolver = Path.(dir resolver / "articles")
  let pages resolver = Path.(dir resolver / "pages")
  let template resolver name = Path.(templates resolver / name)
  let index resolver = Path.(dir resolver / "index.md")

  let css_files resolver =
    [ "reset.css"; "syntax.css"; "style.css" ]
    |> List.map (fun p -> Path.(css resolver / p))
end

module Target = struct
  let dir { target; server; _ } = Path.relocate ~into:target server
  let articles resolver = Path.(dir resolver / "a")

  let page resolver file =
    let into = dir resolver in
    file |> Path.move ~into |> Path.change_extension "html"

  let article resolver file =
    let into = articles resolver in
    file |> Path.move ~into |> Path.change_extension "html"

  let index resolver = Path.(dir resolver / "index.html")
  let css resolver = Path.(dir resolver / "css" / "style.css")
  let atom resolver = Path.(dir resolver / "atom.xml")
  let cache resolver = Path.(dir resolver / "cache")
end

module Server = struct
  let base_url { base_url; _ } = base_url
  let dir { server; _ } = server

  let from_target resolver path =
    let prefix = Target.dir resolver and into = dir resolver in
    path |> Path.trim ~prefix |> Path.relocate ~into

  let url resolver path = base_url resolver ^ Path.to_string path
  let url_from_target resolver path = url resolver (from_target resolver path)
end
