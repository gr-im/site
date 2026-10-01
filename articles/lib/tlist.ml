type (_, _) dir = |
type ord = ([ `Ord ], [ `Rev ]) dir
type rev = ([ `Rev ], [ `Ord ]) dir
type ('ord, 'a) olist = 'a list constraint 'ord = (_, _) dir

let empty = []
let rev_empty = []
let singleton x = [ x ]
let of_list x = x
let rev x = List.rev x
let map f x = List.map f x
let cons x xs = x :: xs
let append xs ys = xs @ ys
let rev_append a b = List.rev_append a b
