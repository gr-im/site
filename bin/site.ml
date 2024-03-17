(* let default_port = 8888 *)
let default_target = "_site"
let run_build target = Yocaml_unix.execute @@ Generator.Rule.all ~target

module Cmd = struct
  open Cmdliner

  let docs = Manpage.s_common_options
  let exits = Cmd.Exit.defaults
  let version = "dev"

  let target_arg =
    let doc =
      Format.asprintf
        "The directory in which the site should be generated (default: [%s])."
        default_target
    in
    let arg = Arg.info ~doc ~docs [ "target" ] in
    Arg.(value @@ opt file default_target arg)

  let build =
    let doc = "Build the website" in
    let info = Cmd.info "build" ~version ~doc ~exits in
    let term = Term.(const run_build $ target_arg) in
    Cmd.v info term

  let index =
    let doc = "Site generator" in
    let info = Cmd.info Sys.argv.(0) ~version ~doc ~sdocs:docs ~exits in
    let default = Term.(ret @@ const (`Help (`Pager, None))) in
    Cmd.group info ~default [ build ]
end

let () =
  let header = Logs_fmt.pp_header in
  let () = Fmt_tty.setup_std_outputs () in
  let () = Logs.set_reporter Logs_fmt.(reporter ~pp_header:header ()) in
  let () = Logs.set_level (Some Logs.Debug) in
  exit @@ Cmdliner.Cmd.eval Cmd.index
