open Yocaml

module type VALIDABLE = Metadata.VALIDABLE
module type INJECTABLE = Key_value.DESCRIBABLE

module Common = struct
  type t = { title : string; description : string; tags : string list }

  let validate (type a) (module V : VALIDABLE with type t = a) o =
    let open Validate.Applicative in
    let open V in
    let+ title = required_assoc string "title" o
    and+ description = required_assoc string "description" o
    and+ tags = optional_assoc_or ~default:[] (list_of string) "tags" o in
    { title; description; tags }

  let inject (type a) (module L : INJECTABLE with type t = a)
      { title; description; tags } =
    L.
      [
        ("title", string title)
      ; ("description", string description)
      ; ("tags", list @@ List.map string tags)
      ; ("has_tags", boolean @@ not (List.is_empty tags))
      ; ("meta_tags", string @@ String.concat ", " tags)
      ]
end

module Ref = struct
  module People = struct
    type t = { ident : string; url : string }

    let validate (type a) (module V : VALIDABLE with type t = a) o =
      let open Validate.Monad in
      let* l = V.list_of V.string o in
      match l with
      | ident :: url :: _ -> Validate.valid { ident; url }
      | _ -> Validate.error @@ Error.Invalid_metadata "Ref.People"

    let to_string l =
      l
      |> List.map (fun { ident; url } -> Format.asprintf {|[%s]: %s|} ident url)
      |> String.concat "\n"
  end

  module Bib = struct
    type t = {
        ident : string
      ; title : string
      ; authors : string list
      ; year : int option
      ; url : string
    }

    let validate (type a) (module V : VALIDABLE with type t = a) o =
      let open Validate.Applicative in
      let open V in
      let+ ident = required_assoc string "ident" o
      and+ title = required_assoc string "title" o
      and+ authors = required_assoc (list_of string) "authors" o
      and+ year = optional_assoc integer "year" o
      and+ url = required_assoc string "url" o in
      { ident; title; authors; year; url }

    let from (type a) (module V : VALIDABLE with type t = a) obj =
      V.object_and (validate (module V)) obj

    let to_string l =
      l
      |> List.map (fun { ident; url; _ } ->
             Format.asprintf {|[%s]: %s|} ident url)
      |> String.concat "\n"

    let inject (type a) (module L : INJECTABLE with type t = a)
        { ident = _; title; authors; year; url } =
      L.
        [
          ("title", string title)
        ; ("authors", list @@ List.map string authors)
        ; ("has_year", boolean @@ Option.is_some year)
        ; ("year", Option.fold ~none:null ~some:integer year)
        ; ("url", string url)
        ]
  end
end

module Page = struct
  type t = { common : Common.t }

  let validate (type a) (module V : VALIDABLE with type t = a) o =
    let open Validate.Applicative in
    let+ common = Common.validate (module V) o in
    { common }

  let from (type a) (module V : VALIDABLE with type t = a) obj =
    V.object_and (validate (module V)) obj

  let from_string (module V : VALIDABLE) = function
    | None -> Error.(to_validate @@ Required_metadata [ "Page" ])
    | Some s -> Validate.Monad.(s |> V.from_string >>= from (module V))

  let inject (type a) (module L : INJECTABLE with type t = a) { common } =
    Common.inject (module L) common @ []
end

module Article = struct
  type t = {
      common : Common.t
    ; date : Metadata.Date.t
    ; referenced_people : Ref.People.t list
    ; bib : Ref.Bib.t list
  }

  let validate (type a) (module V : VALIDABLE with type t = a) o =
    let open Validate.Applicative in
    let open V in
    let+ common = Common.validate (module V) o
    and+ date = required_assoc (Metadata.Date.from (module V)) "date" o
    and+ bib =
      optional_assoc_or ~default:[] (list_of @@ Ref.Bib.from (module V)) "bib" o
    and+ referenced_people =
      optional_assoc_or ~default:[]
        (list_of @@ Ref.People.validate (module V))
        "referenced_people" o
    in
    { common; date; referenced_people; bib }

  let from (type a) (module V : VALIDABLE with type t = a) obj =
    V.object_and (validate (module V)) obj

  let from_string (module V : VALIDABLE) = function
    | None -> Error.(to_validate @@ Required_metadata [ "Article" ])
    | Some s -> Validate.Monad.(s |> V.from_string >>= from (module V))

  let inject (type a) (module L : INJECTABLE with type t = a)
      { common; date; bib; referenced_people = _ } =
    Common.inject (module L) common
    @ L.
        [
          ("date", object_ @@ Metadata.Date.inject (module L) date)
        ; ("has_bib", boolean @@ not (List.is_empty bib))
        ; ( "bib"
          , list
            @@ List.map (fun x -> object_ @@ Ref.Bib.inject (module L) x) bib )
        ]

  let prepare =
    Build.arrow (fun (meta, content) ->
        ( meta
        , content
          ^ "\n\n"
          ^ Ref.People.to_string meta.referenced_people
          ^ "\n"
          ^ Ref.Bib.to_string meta.bib ))
end

module Articles = struct
  type t = { common : Common.t; articles : (Article.t * string) list }

  let get_article (module V : VALIDABLE) file =
    let arr = Build.read_file_with_metadata (module V) (module Article) file in
    let deps = Build.get_dependencies arr in
    let task = Build.get_task arr in
    let+ meta, _ = task () in
    (deps, (meta, Filepath.(basename @@ replace_extension file "html")))

  let all (module V : VALIDABLE) =
    let* files = read_child_files "articles" (Filepath.with_extension "md") in
    let+ articles = Traverse.traverse (get_article (module V)) files in
    let deps, articles =
      Preface.Pair.Bifunctor.bimap Deps.Monoid.reduce (fun x ->
          List.sort
            (fun (a, _) (b, _) -> Date.compare b.Article.date a.Article.date)
            x)
      @@ List.split articles
    in
    Build.make deps (fun (meta, content) ->
        return ({ meta with articles }, content))

  let validate (type a) (module V : VALIDABLE with type t = a) o =
    let open Validate.Applicative in
    let+ common = Common.validate (module V) o in
    { common; articles = [] }

  let from (type a) (module V : VALIDABLE with type t = a) obj =
    V.object_and (validate (module V)) obj

  let from_string (module V : VALIDABLE) = function
    | None -> Error.(to_validate @@ Required_metadata [ "Articles" ])
    | Some s -> Validate.Monad.(s |> V.from_string >>= from (module V))

  let inject (type a) (module L : INJECTABLE with type t = a)
      { common; articles } =
    let articles =
      List.map
        (fun (article, url) ->
          let a = Article.inject (module L) article in
          L.object_ (("url", L.string url) :: a))
        articles
    in
    Common.inject (module L) common @ [ ("articles", L.list articles) ]
end
