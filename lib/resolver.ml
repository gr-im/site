open Yocaml

let css ~target = Path.(target / "css" / "style.css")

let page ~target page_file =
  page_file |> Path.move ~into:target |> Path.change_extension "html"

let article ~target article_file =
  article_file
  |> Path.(move ~into:(target / "a"))
  |> Path.change_extension "html"
