module Page : sig
  type t

  include Yocaml.Required.DATA_READABLE with type t := t
  include Yocaml.Required.DATA_INJECTABLE with type t := t
end

module Article : sig
  type t

  val prepare : (t * string, t * string) Yocaml.Task.t

  include Yocaml.Required.DATA_READABLE with type t := t
  include Yocaml.Required.DATA_INJECTABLE with type t := t
end

module Articles : sig
  type t

  val index : Resolver.t -> Yocaml.Path.t -> (Page.t, t) Yocaml.Task.t
  val to_atom : Resolver.t -> Yocaml.Path.t -> (unit, string) Yocaml.Task.t

  include Yocaml.Required.DATA_READABLE with type t := t
  include Yocaml.Required.DATA_INJECTABLE with type t := t
end
