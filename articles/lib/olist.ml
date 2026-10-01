type rev = [ `Rev ]
type ord = [ `Ord ]
type ('ord, 'a) olist = 'a list constraint 'ord = [< rev | ord ]

let empty = []
let rev_empty = []
let singleton x = [ x ]
let of_list x = x
let rev x = List.rev x
let ord x = List.rev x
let map f x = List.map f x
let cons x xs = x :: xs
let append xs ys = xs @ ys
let rev_append a b = List.rev_append a b
