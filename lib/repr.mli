module Page : sig
  type t

  include Yocaml.Required.DATA_READABLE with type t := t
  include Yocaml.Required.DATA_INJECTABLE with type t := t
end

module Article : sig
  type t

  val add_footer : t -> string -> string

  include Yocaml.Required.DATA_READABLE with type t := t
  include Yocaml.Required.DATA_INJECTABLE with type t := t
end

module Articles : sig
  type t

  val fetch :
       Resolver.t
    -> Yocaml.Path.t
    -> (unit, (Yocaml.Path.t * Article.t) list) Yocaml.Task.t

  val from_page : Page.t -> (Yocaml.Path.t * Article.t) list -> t

  val to_atom :
       Resolver.t
    -> Yocaml.Path.t
    -> (unit, Yocaml_syndication.Xml.t) Yocaml.Task.t

  include Yocaml.Required.DATA_READABLE with type t := t
  include Yocaml.Required.DATA_INJECTABLE with type t := t
end
