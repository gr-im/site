type t

val make :
     ?source:Yocaml.Path.t
  -> ?target:Yocaml.Path.t
  -> ?server:Yocaml.Path.t
  -> base_url:string
  -> unit
  -> t

module Source : sig
  val dir : t -> Yocaml.Path.t
  val articles : t -> Yocaml.Path.t
  val pages : t -> Yocaml.Path.t
  val index : t -> Yocaml.Path.t
  val css_files : t -> Yocaml.Path.t list
  val template : t -> string -> Yocaml.Path.t
end

module Target : sig
  val dir : t -> Yocaml.Path.t
  val page : t -> Yocaml.Path.t -> Yocaml.Path.t
  val article : t -> Yocaml.Path.t -> Yocaml.Path.t
  val index : t -> Yocaml.Path.t
  val css : t -> Yocaml.Path.t
  val atom : t -> Yocaml.Path.t
  val cache : t -> Yocaml.Path.t
end

module Server : sig
  val base_url : t -> string
  val dir : t -> Yocaml.Path.t
  val from_target : t -> Yocaml.Path.t -> Yocaml.Path.t
  val url : t -> Yocaml.Path.t -> string
  val url_from_target : t -> Yocaml.Path.t -> string
end
