open Yocaml.Filepath

let css ~target = "style.css" |> into "css" |> into target

let page ~target page_file =
  basename @@ replace_extension page_file "html" |> into target

let article ~target article_file =
  basename @@ replace_extension article_file "html" |> into "a" |> into target
