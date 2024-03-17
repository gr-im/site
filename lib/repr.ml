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
      ]
end

module Article = struct
  type t = { common : Common.t; has_toc : bool }

  let validate (type a) (module V : VALIDABLE with type t = a) o =
    let open Validate.Applicative in
    let open V in
    let+ common = Common.validate (module V) o
    and+ has_toc = optional_assoc_or ~default:true boolean "has_toc" o in
    { common; has_toc }

  let from (type a) (module V : VALIDABLE with type t = a) obj =
    V.object_and (validate (module V)) obj

  let from_string (module V : VALIDABLE) = function
    | None -> Error.(to_validate @@ Required_metadata [ "Article" ])
    | Some s -> Validate.Monad.(s |> V.from_string >>= from (module V))

  let inject (type a) (module L : INJECTABLE with type t = a)
      { common; has_toc } =
    Common.inject (module L) common @ L.[ ("has_toc", boolean has_toc) ]
end
