module Page : sig
  type t

  include Yocaml.Metadata.READABLE with type t := t
  include Yocaml.Metadata.INJECTABLE with type t := t
end

module Article : sig
  type t

  val prepare : (t * string, t * string) Yocaml.Build.t

  include Yocaml.Metadata.READABLE with type t := t
  include Yocaml.Metadata.INJECTABLE with type t := t
end

module Articles : sig
  type t

  val all :
       (module Yocaml.Metadata.VALIDABLE)
    -> (t * string, t * string) Yocaml.Build.t Yocaml.t

  include Yocaml.Metadata.READABLE with type t := t
  include Yocaml.Metadata.INJECTABLE with type t := t
end
