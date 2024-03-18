open Yocaml

let from_string ~strict content =
  content
  |> Cmarkit.Doc.of_string ~strict ~heading_auto_ids:true
  |> Cmarkit_html.of_doc ~safe:false

let to_html ~strict = Build.arrow @@ from_string ~strict
