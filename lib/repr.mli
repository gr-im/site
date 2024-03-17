(** Describes the different representations used in the website (page models) *)

module Article : sig
  (** The heart of the application is a list of items. This module describes how
      these items are represented. *)

  type t
  (** An article is a value of type [t]. *)

  include Yocaml.Metadata.READABLE with type t := t
  include Yocaml.Metadata.INJECTABLE with type t := t
end
