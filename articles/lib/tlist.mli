type (_, _) dir
type ord = ([ `Ord ], [ `Rev ]) dir
type rev = ([ `Rev ], [ `Ord ]) dir
type ('ord, 'a) olist = private 'a list constraint 'ord = (_, _) dir

val empty : (ord, 'a) olist
val rev_empty : (rev, 'a) olist
val singleton : 'a -> (ord, 'a) olist
val of_list : 'a list -> (ord, 'a) olist
val cons : 'a -> (rev, 'a) olist -> (rev, 'a) olist
val append : (ord, 'a) olist -> (ord, 'a) olist -> (ord, 'a) olist
val rev : (('o, 'r) dir, 'a) olist -> (('r, 'o) dir, 'a) olist
val map : ('a -> 'b) -> ('k, 'a) olist -> ('k, 'b) olist
val rev_append : (rev, 'a) olist -> (ord, 'a) olist -> (ord, 'a) olist
