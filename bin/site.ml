let default_port = 8888
let default_target = "_site"
let run_build target = Yocaml_unix.execute @@ Generator.Rule.all ~target

let run_watch target port =
  let server =
    Yocaml_unix.serve ~filepath:target ~port @@ Generator.Rule.all ~target
  in
  let () = run_build target in
  Lwt_main.run server

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
    let arg = Arg.info ~doc ~docs [ "target"; "output" ] in
    Arg.(value @@ opt file default_target arg)

  let port_arg =
    let doc =
      Format.asprintf "The port the server must listen to  (default: [%d])."
        default_port
    in
    let arg = Arg.info ~doc ~docs [ "port"; "P" ] in
    Arg.(value @@ opt int default_port arg)

  let build =
    let doc = "Build the website" in
    let info = Cmd.info "build" ~version ~doc ~exits in
    let term = Term.(const run_build $ target_arg) in
    Cmd.v info term

  let watch =
    let doc =
      "Serves the target content as an HTTP server (on the given port) and \
       rebuilds the site on each request."
    in
    let info = Cmd.info "watch" ~version ~doc ~exits in
    let term = Term.(const run_watch $ target_arg $ port_arg) in
    Cmd.v info term

  let index =
    let doc = "Site generator" in
    let info = Cmd.info Sys.argv.(0) ~version ~doc ~sdocs:docs ~exits in
    let default = Term.(ret @@ const (`Help (`Pager, None))) in
    Cmd.group info ~default [ build; watch ]
end

let () =
  let header = Logs_fmt.pp_header in
  let () = Fmt_tty.setup_std_outputs () in
  let () = Logs.set_reporter Logs_fmt.(reporter ~pp_header:header ()) in
  let () = Logs.set_level (Some Logs.Debug) in
  exit @@ Cmdliner.Cmd.eval Cmd.index
