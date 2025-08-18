module type M = sig
  type 'a t

  val return : 'a -> 'a t
  val map : ('a -> 'b) -> 'a t -> 'b t
  val ap : ('a -> 'b) t -> 'a t -> 'b t
  val bind : 'a t -> ('a -> 'b t) -> 'b t
end

module ID : M with type 'a t = 'a = struct
  type 'a t = 'a

  let return x = x
  let map f = f
  let bind x f = f x
  let ap f = f
end

module RT : sig
  type ('a, 'b) t

  val handle : 'b -> ('a, 'b) t -> 'a ID.t
  val perform : ('b -> 'a ID.t) -> ('a, 'b) t
  val return : 'a -> ('a, 'b) t
  val map : ('a -> 'b) -> ('a, 'c) t -> ('b, 'c) t
  val ap : ('a -> 'b, 'c) t -> ('a, 'c) t -> ('b, 'c) t
  val bind : ('a, 'c) t -> ('a -> ('b, 'c) t) -> ('b, 'c) t
  val ( let* ) : ('a, 'c) t -> ('a -> ('b, 'c) t) -> ('b, 'c) t
  val ( let+ ) : ('a, 'c) t -> ('a -> 'b) -> ('b, 'c) t
  val ( and+ ) : ('a, 'c) t -> ('b, 'c) t -> ('a * 'b, 'c) t
end = struct
  type ('a, 'b) t = 'b -> 'a ID.t

  let perform f = f
  let handle env reader = reader env
  let return x = Fun.const (ID.return x)
  let map f r x = (ID.map f) (r x)
  let ap ra rb x = ID.ap (ra x) (rb x)
  let bind r f x = ID.bind (r x) (fun y -> (f y) x)
  let ( let* ) = bind
  let ( let+ ) x f = map f x
  let ( and+ ) a b = ap (ap (return (fun a b -> (a, b))) a) b
end

let of_markdown x = String.trim x

let comp () =
  let open RT in
  let* x = perform (fun handler -> handler#read_file "hello.md") in
  let+ () = perform (fun handler -> handler#log "This is a log") in
  of_markdown x

class fs =
  object
    method read_file (path : string) = path
  end

class console =
  object
    method log x = print_endline x
  end

(* let x = *)
(*   RT.handle *)
(*     (object *)
(*        inherit fs *)
(*        inherit console *)
(*     end) *)
(*     (comp ()) *)

module Env : sig
  type ('normal_form, 'rows) t

  val run : 'rows -> ('normal_form, 'rows) t -> 'normal_form
  val perform : ('rows -> 'normal_form) -> ('normal_form, 'rows) t
  val return : 'normal_form -> ('normal_form, 'rows) t
  val ( let* ) : ('a, 'rows) t -> ('a -> ('b, 'rows) t) -> ('b, 'rows) t
end = struct
  type ('normal_form, 'rows) t = 'rows -> 'normal_form

  let run env comp = comp env
  let perform f = f
  let return x _ = x
  let ( let* ) r f x = (fun y -> (f y) x) (r x)
end
