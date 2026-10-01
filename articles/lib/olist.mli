type rev = [ `Rev ]
type ord = [ `Ord ]
type ('ord, 'a) olist = private 'a list constraint 'ord = [< rev | ord ]

val empty : (ord, 'a) olist
val rev_empty : (rev, 'a) olist
val singleton : 'a -> (ord, 'a) olist
val of_list : 'a list -> (ord, 'a) olist
val cons : 'a -> (rev, 'a) olist -> (rev, 'a) olist
val append : (ord, 'a) olist -> (ord, 'a) olist -> (ord, 'a) olist
val rev : (ord, 'a) olist -> (rev, 'a) olist
val ord : (rev, 'a) olist -> (ord, 'a) olist
val map : ('a -> 'b) -> ('k, 'a) olist -> ('k, 'b) olist
val rev_append : (rev, 'a) olist -> (ord, 'a) olist -> (ord, 'a) olist
