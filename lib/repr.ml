open Yocaml

let base_url = "https://gr-im.github.io"
let feed_url = base_url ^ "/" ^ "atom.xml"

let owner =
  Yocaml_syndication.Person.make ~uri:base_url ~email:"grimfw@gmail.com" "Grim"

module Page = struct
  type t = { title : string; description : string; tags : string list }

  let entity_name = "Page"
  let neutral = Metadata.required entity_name

  let validate_underlying_page fields =
    let open Data.Validation in
    let+ title = required fields "title" string
    and+ description = required fields "description" string
    and+ tags = optional_or fields ~default:[] "tags" (list_of string) in
    { title; description; tags }

  let validate = Data.Validation.record validate_underlying_page

  let normalize { title; description; tags } =
    let open Data in
    [
      ("title", string title)
    ; ("description", string description)
    ; ("has_tags", bool @@ not (List.is_empty tags))
    ; ("tags", list_of string tags)
    ; ("meta_tags", string @@ String.concat ", " tags)
    ]
end

let list_to_bib f list =
  List.fold_left
    (fun acc elt ->
      let ident, url = f elt in
      acc ^ Format.asprintf "[%s]: %s" ident url ^ "\n")
    "" list

module Human = struct
  type t = { ident : string; url : string }

  let validate x =
    let open Data.Validation in
    let* humans = list_of string x in
    match humans with
    | ident :: url :: _ -> Ok { ident; url }
    | _ -> fail_with ~given:"human list" "Invalid list of humans"

  let to_string = list_to_bib (fun { ident; url } -> (ident, url))
end

module Bib = struct
  type t = {
      ident : string
    ; title : string
    ; authors : string list
    ; year : int option
    ; url : string
  }

  let valdiate =
    let open Data.Validation in
    record (fun fields ->
        let+ ident = required fields "ident" string
        and+ title = required fields "title" string
        and+ authors = required fields "authors" (list_of string)
        and+ year = optional fields "year" int
        and+ url = required fields "url" string in
        { ident; title; authors; year; url })

  let normalize { title; authors; year; url; _ } =
    let open Data in
    record
      [
        ("title", string title)
      ; ("authors", list_of string authors)
      ; ("year", option int year)
      ; ("url", string url)
      ]

  let to_string = list_to_bib (fun { ident; url; _ } -> (ident, url))
end

module Article = struct
  type t = {
      page : Page.t
    ; date : Archetype.Datetime.t
    ; referenced_humans : Human.t list
    ; bib : Bib.t list
  }

  let entity_name = "Article"
  let neutral = Metadata.required entity_name

  let validate =
    let open Data.Validation in
    record (fun fields ->
        let+ page = Page.validate_underlying_page fields
        and+ date = required fields "date" Archetype.Datetime.validate
        and+ bib = optional_or fields "bib" ~default:[] (list_of Bib.valdiate)
        and+ referenced_humans =
          optional_or fields "referenced_humans" ~default:[]
            (list_of @@ Human.validate)
        in

        { page; date; referenced_humans; bib })

  let normalize { page; date; bib; _ } =
    let open Yocaml.Data in
    Page.normalize page
    @ [
        ("date", Archetype.Datetime.normalize date)
      ; ("has_bib", bool (not (List.is_empty bib)))
      ; ("bib", list_of Bib.normalize bib)
      ]

  let prepare =
    Task.lift ~has_dynamic_dependencies:false (fun (meta, content) ->
        ( meta
        , content
          ^ "\n\n"
          ^ Human.to_string meta.referenced_humans
          ^ Bib.to_string meta.bib ))

  let compare { date = a; _ } { date = b; _ } = Archetype.Datetime.compare a b

  let to_atom_entry (url, { page; date; _ }) =
    let open Yocaml_syndication in
    let title = page.title in
    let url = base_url ^ Path.to_string url in
    let updated = Datetime.make date in
    let categories = List.map Category.make page.tags in
    let summary = Atom.text page.description in
    let links = [ Atom.alternate url ~title ] in
    Atom.entry ~links ~categories ~summary ~updated ~id:url
      ~title:(Atom.text title) ()
end

module Articles = struct
  type t = { page : Page.t; articles : (Path.t * Article.t) list }

  let entity_name = "Articles"
  let neutral = Metadata.required entity_name

  let validate =
    let open Data.Validation in
    record (fun fields ->
        let+ page = Page.validate_underlying_page fields in
        { page; articles = [] })

  let article (url, article) =
    let open Data in
    record (("url", string @@ Path.to_string url) :: Article.normalize article)

  let from_page = Task.lift (fun (page, articles) -> { page; articles })

  let normalize { page; articles } =
    let open Data in
    ("has_articles", bool @@ not (List.is_empty articles))
    :: ("articles", list_of article articles)
    :: Page.normalize page

  let sort = List.sort (fun (_, a) (_, b) -> ~-(Article.compare a b))

  let fetch path =
    Task.from_effect (fun () ->
        let open Eff in
        let* files =
          read_directory ~on:`Source ~only:`Files path
            ~where:(Path.has_extension "md")
        in
        let+ articles =
          List.traverse
            (fun file ->
              let url =
                Path.(
                  file
                  |> move ~into:(Path.abs [ "a" ])
                  |> change_extension "html")
              in
              let+ meta, _ =
                Eff.read_file_with_metadata
                  (module Yocaml_yaml)
                  (module Article)
                  ~on:`Source file
              in
              (url, meta))
            files
        in
        articles |> sort)

  let index path =
    let open Task in
    lift (fun x -> (x, ())) >>> second (fetch path) >>> from_page

  let to_atom path =
    let open Task in
    let open Yocaml_syndication in
    let id = feed_url in
    let title = Atom.text "Grim's web corner" in
    let subtitle = Atom.text "Notes, essays and ramblings" in
    let links = [ Atom.self feed_url; Atom.link base_url ] in
    let updated = Atom.updated_from_entries () in
    let authors = Yocaml.Nel.singleton owner in
    fetch path
    >>> Atom.from ~updated ~title ~subtitle ~id ~links ~authors
          Article.to_atom_entry
end
