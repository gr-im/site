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

  val index : Yocaml.Path.t -> (Page.t, t) Yocaml.Task.t

  include Yocaml.Required.DATA_READABLE with type t := t
  include Yocaml.Required.DATA_INJECTABLE with type t := t
end
