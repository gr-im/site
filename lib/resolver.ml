open Yocaml.Filepath

let css ~target = "style.css" |> into "css" |> into target
