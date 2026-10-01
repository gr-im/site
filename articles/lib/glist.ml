type rev = private R
type ord = private O

type (_, _) t =
  | [] : (rev, 'a) t
  | ( :: ) : 'a * (rev, 'a) t -> (rev, 'a) t
  | Ord : (rev, 'a) t -> (ord, 'a) t

let rev_empty = []
let ord list = Ord list
let empty = Ord rev_empty

let of_rev_list list =
  let rec aux : (rev, 'a) t -> 'a list -> (rev, 'a) t =
   fun acc -> function
     | [] -> acc
     | x :: xs -> aux (x :: acc) xs
  in
  aux [] list

let of_list list = list |> of_rev_list |> ord

let to_list : type a. (a, 'b) t -> 'b list =
 fun xs ->
  let rec aux : 'b list -> (rev, 'b) t -> 'b list =
   fun acc -> function
     | [] -> acc
     | x :: xs -> aux (x :: acc) xs
  in
  match xs with
  | Ord xs -> aux [] xs
  | ([] | _ :: _) as xs -> List.rev (aux [] xs)

let map : type a. ('b -> 'c) -> (a, 'b) t -> (a, 'c) t =
 fun f xs ->
  let rec aux : (rev, 'c) t -> (rev, 'b) t -> (rev, 'c) t =
   fun acc -> function
     | [] -> acc
     | x :: xs -> aux (f x :: acc) xs
  in
  match xs with
  | Ord xs -> Ord (aux [] xs)
  | [] -> []
  | _ :: _ as xs -> aux [] xs
