let css ~target =
  let open Yocaml.Build in
  let target = Resolver.css ~target in
  create_file target (read_file "css/reset.css" >>> pipe_content "css/style.css")

let all ~target =
  let open Yocaml.Effect in
  let* () = css ~target in
  return ()
