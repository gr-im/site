---
title: Lists that keep track of their reversal
date: 2026-09-30
description:
  Summary of a small discussion on how to track, at type level, whether a list is 
  constructed forwards or backwards. It remains to be seen whether this will 
  be useful in everyday life, but the proposal is driven by a specific issue.
referenced_humans:
  - [misterda, https://github.com/MisterDA]
  - [octachron, https://github.com/octachron]
  - [xvw, https://xvw.lol/en]
bib:
  - ident: nel
    title: "cargocut/nel"
    year: 2026
    url: https://github.com/cargocut/nel
    authors: [Mickael Spawn, Cargocut]
  - ident: nel-issue
    title: "A type for ordered lists?"
    year: 2026 
    url: https://github.com/cargocut/nel/issues/2
    authors: [Antonin Décimo]
  - ident: discuss
    title: "OCaml.org: A type for ordered lists?"
    url: https://discuss.ocaml.org/t/a-type-for-ordered-lists/18567
    year: 2023
    authors: [Antonin Décimo]
  - ident: merlin-1737
    title: "Destruct: Removal of Residual patterns fix"
    authors: [Xavier Van de Woestyne]
    year: 2024
    url: https://github.com/ocaml/merlin/pull/1737
  - ident: trmc
    title: "The “Tail Modulo Constructor” program transformation"
    url: https://ocaml.org/manual/5.1/tail_mod_cons.html
    year: 2023
    authors: 
      - Xavier Leroy
      - Damien Doligez
      - Alain Frisch
      - Jacques Garrigue
      - Didier Rémy
      - KC Sivaramakrishnna
      - Jérôme Vouillon
  - ident: ocaml-7028
    title: "GADT pattern exhaustiveness checking and abstract types"
    url: https://github.com/ocaml/ocaml/issues/7028
    authors: [ Alain Frisch, Gabriel Scherer ]
  - ident: phantom
    title: "What about phantom types"
    url: https://raphael-proust.gitlab.io/code/gadt-what-about-phantom-types.html
    year: 2026
    authors: [ Raphaël Proust ]
---

<div class="hidden-block">

```ocaml
# open Article_lib ;;
```

</div>

Recently, we ([Cargocut](https://github.com/cargocut), a collective
_enthusiastic and amused_ by the use of OCaml) released the [nel][nel]
package, a tiny library (_with a very modest API_) for describing
**non-empty lists** (containing at least one element, for which the
pair of functions `hd/tl` is total). The purpose of this data
structure is to serve as an error buffer for our
[Pidgin](https://github.com/cargocut/pidgin) library, in the context
of [applicative
validation](https://hackage.haskell.org/package/validation), ensuring
that in the event of an error, we have at least one error (thanks to
the semigroup nature of a non-empty list). Even though the
implementation is very straightforward and naive:

```ocaml
type 'a t = 
  | ( :: ) of 'a * 'a list
```

However, even though it is naively trivial, this data structure shows
that sometimes we want to use _something that looks like a list, but
maintains more invariants_ (in this case, the presence of **at least
one element**). This is probably why we were fortunate enough to see a
[discussion started as an issue][nel-issue] by [Antonin
Décimo][misterda] (one of the
[maintainers](https://github.com/ocaml/ocaml/blob/trunk/CONTRIBUTING.md#maintainers)
of [OCaml](https://ocaml.org), notably known for his [extensive
contributions](https://github.com/ocaml/ocaml/pulls?q=is%3Apr+state%3Aclosed+author%3AMisterDA)
to the OCaml _runtime_).

Since the goal of `nel` is to remain a tiny _single-purpose_ library,
this discussion probably did not belong in the most appropriate place
(which is why the issue was closed and converted into a [Discuss
thread][discuss]). Nevertheless, it illustrates that some developers
would like to have more invariants for such common constructs as
lists, for example. In the rest of this article, I will describe
Antonin's proposal in my own words, as simply as possible, and then
present several implementations.


## To `rev` or not to `rev`, that's the question

Lists are very convenient to use in OCaml, as they work well with
recursion (thanks to their recursive definition) and pattern matching
(`[]` and `::` are standard OCaml constructors that can be used to
define a slightly different _zoology of lists_, brilliantly
_non-prefixable_ through
[disambiguation](https://ocaml.org/manual/5.0/coreexamples.html#ss:record-and-variant-disambiguation)).

As Antonin points out, OCaml programmers make extensive use of
_folding_, _mapping_, and list concatenation, while keeping
_tail-recursion_ in mind whenever possible (even though [`Tail
Recursion Modulo Constructor`][trmc] makes the traditional approaches
trivial). Indeed, for reasons of _complexity_ and _nesting_, it is
preferable to build a list by prepending elements, then reverse it at
the end of the traversal, rather than append elements to its tail.
For example, here is a naive implementation of `map`:

```ocaml
let map f list = 
  let rec aux acc = function 
    | [] -> List.rev acc 
    | x :: xs -> aux (f x :: acc) xs
  in aux [] list
```
Usually, the **implicit invariant that the list is being built in
reverse order** is local and fairly easy to reason about. However, as
Antonin explains, one is quickly tempted to add a collection of
_Hungarian-prefix-style_ functions (using `rev_*`, in [his own
words][discuss]), as demonstrated by the existence of functions such
as `rev_append`, `rev_map`, `rev_iter`, _etc._ According to him, this
is why **we need to track the construction order in the type of a
potential list**.

Amusingly, when I first read [the issue][nel-issue], my initial
intuition was that this was probably a lot of work to capture local
invariants. After thinking about it, I realised that this was
essentially a lack of motivation that could be applied to static
typing in general: "_why bother with types when we can be careful and
write tests_". However, when working with type systems of varying
levels of expressiveness, we generally try to strike a _trade-off_
between static guarantees and usability. Typing things too precisely,
even when a language allows it, can unfortunately sometimes make code
more complicated to use.

After briefly discussing it with [Xavier Van de Woestyne][xvw], we
quickly realised that the invariant we had considered local, building
a list in reverse order, **wasn't quite so local after all**. Indeed,
the existence of `rev_append` (and, by extension, `rev_map`) points
quite clearly to the fact that, for performance reasons, we prefer to
**leave the responsibility for reversing a list to the caller** (for
example, when appending it to the end of another list built in a
different way). We were even fortunate enough to find a very concrete
example of this constraint being relaxed in one of Xavier's earliest
contributions to [Merlin](https://github.com/ocaml/merlin):
["_destruct: Removal of residual patterns_"][merlin-1737]. Tracking
**whether or not a list needs to be reversed** seems useful for
certain classes of problems.

Although this was outside the scope of the `nel` library, the exercise
was entertaining enough to be worth trying (and could potentially
lead to a useful library). While Antonin calls for _type wizards_,
which I am most definitely not, I'll present a few ideas I came up
with in the next section.

### A first _by-construction_ approach

As is often the case in OCaml, when we want to enforce properties by
construction, we turn to
[GADTs](https://ocaml.org/manual/5.2/gadts-tutorial.html), which allow
us to encode constraints on type parameters _through constructors_
(using local type equalities). First, I define some _tags_ that will
allow me to index reversed and non-reversed lists:

```ocaml
type rev = private R
type ord = private O
```

> I give them constructors so that, outside the module, the compiler
> considers `rev` and `ord` to be distinct (if they are abstract), as
> discussed in ["GADT pattern exhaustiveness checking and abstract
> types"][ocaml-7028]. The private marker is, here, purely cosmetic,
> as I don't want them to be used for anything other than tagging. But
> it is probably unnecessary.

The second step is to describe a list type that maintains this _tag_.
Since, at the constructor level, the only way to construct a list is
to use `::` and `[]`, we can assert that **every list construction is
reversed** when we only use the constructors:


```ocaml
type (_, _) glist =
  | [] : (rev, 'a) glist
  | ( :: ) : 'a * (rev, 'a) glist -> (rev, 'a) glist
```

This way, **we can only construct reversed lists**, for example (_I
haven't installed any pretty-printers for my type, so reading it is a
little cumbersome_):

```ocaml
# [1] ;;
- : (rev, int) glist = (::) (1, [])
```

We can see that `[1]` (which is actually `1 :: []`) correctly returns
a list whose tag is `rev`. Now, we would also like to be able to
describe _non-reversed_ lists (otherwise the module would not be
particularly useful). My idea is simply to add a constructor whose
purpose is **to reverse a reversed list**:

<div class="hidden-block">

```ocaml
type (_, _) glist =
  | [] : (rev, 'a) glist
  | ( :: ) : 'a * (rev, 'a) glist -> (rev, 'a) glist
  | Ord : (rev, 'a) glist -> (ord, 'a) glist
```

</div>


```diff
 type (_, _) glist =
   | [] : (rev, 'a) glist
   | ( :: ) : 'a * (rev, 'a) t -> (rev, 'a) glist
+  | Ord : (rev, 'a) t -> (ord, 'a) glist
```

We can now build some useful combinators and let type inference guide
us to ensure that the tags are assigned correctly:

```ocaml
# let rev_empty = [] ;;
val rev_empty : (rev, 'a) glist = []
# let empty = Ord [] ;;
val empty : (ord, 'a) glist = Ord []
# let ord l = Ord l ;;
val ord : (rev, 'a) glist -> (ord, 'a) glist = <fun>
```

The _counter-intuitive_ part of this definition is that we never
actually reverse (reorder) the list. To do this, we will start by
creating two functions:


<!-- $MDX skip -->
```ocaml
val of_rev_list : 'a list -> (rev, 'a) glist
val of_list : 'a list -> (ord, 'a) glist
```

The intuition behind the types of these two functions should be
enough: the first simply builds a reversed list _from an already
reversed list_, while the second builds a list _from a non-reversed
list_. Let's start by implementing `of_rev_list`:

```ocaml
let of_rev_list list =
  let rec aux : (rev, 'a) glist -> 'a list -> (rev, 'a) glist =
   fun acc -> function
     | [] -> acc
     | x :: xs -> aux (x :: acc) xs
  in
  aux [] list
```

We will traverse all the elements of our list and progressively
reconstruct a `glist`. What _may seem strange_ is that the list is
being built in reverse:

```ocaml
# of_rev_list [1; 2; 3] ;;
- : (rev, int) glist = (::) (3, (::) (2, (::) (1, [])))
```

However, the _actual_ reversal (the projection to regular lists) will
take place later. To transform a non-reversed list, we already have
`ord`, so the function is trivial to implement:


```ocaml
let of_list list = 
  list 
  |> of_rev_list 
  |> ord
```

The fun part (from my perspective) of this encoding is that a
non-reversed list has exactly the same structure as a reversed list
(which reinforces its somewhat strange nature). Indeed, the only
difference is that a non-reversed list is wrapped in the `Ord`
constructor, which maintains the `ord` tag:

```ocaml
# of_list [1; 2; 3] ;;
- : (ord, int) glist = Ord ((::) (3, (::) (2, (::) (1, []))))
```

Now that we can construct lists _from scratch_ and from existing
regular lists, we can **actually perform the reversal** by providing
the `to_list` combinator:

```ocaml
(* We want to be able to process lists of two types 
 ([rev] list and [ord] list) *)
let to_list : type a. (a, 'b) glist -> 'b list = fun glist -> 
  (* First, we only deal with rev list *)
  let rec aux : 'b list -> (rev, 'b) glist -> 'b list = 
    fun acc -> function 
    | [] -> acc 
    | x :: xs -> aux (x :: acc) xs
  in match glist with 
  | Ord xs -> 
     (* The list was already reversed by [aux] *)
     aux [] xs
  | ([] | _ :: _) as xs ->
     (* We get a reversed list, so let's reverse it *)
     List.rev (aux [] xs)
```

We now have enough tools **to track reversal** in the type. Let's
imagine, for example, that we implement a `map` function on regular
lists that does not reverse its final result:

```ocaml
# let my_map f list =
    let rec aux acc = function 
      | List.[] -> acc 
      | List.(x :: xs) -> aux (f x :: acc) xs
    in aux [] list ;;
val my_map : ('a -> 'b) -> 'a list -> (rev, 'b) glist = <fun>
```

We can quickly test this. As expected, our result should be reversed:

```ocaml
# [1; 2; 3; 4; 5] |> my_map (fun x -> x + 42) |> to_list ;;
- : int list = [47; 46; 45; 44; 43]
```

We can also make sure that _un-reversing_ works, using the `ord`
function:

```ocaml
# [1; 2; 3; 4; 5] |> my_map (fun x -> x + 42) |> ord |> to_list ;;
- : int list = [43; 44; 45; 46; 47]
```

And even though the purpose of this type is probably not to build
indexed lists only to convert them back into regular lists, we can
still build common functions, such as _mapping_ over our `glist`s,
which, of course, preserve their tags (mapping over a list does not
change its _reversal_):

```ocaml
let map : type a. ('b -> 'c) -> (a, 'b) glist -> (a, 'c) glist =
 fun f xs ->
  let rec aux : (rev, 'c) glist -> (rev, 'b) glist -> (rev, 'c) glist =
   fun acc -> function
     | [] -> acc
     | x :: xs -> aux (f x :: acc) xs
  in
  match xs with
  | Ord xs -> Ord (aux [] xs)
  | [] -> []
  | _ :: _ as xs -> aux [] xs
```

The problem _seems solved_, however, attentive readers will have
noticed several major weaknesses in this proposal (which is why I
didn't share it in [the original discussion][nel-issue]). Indeed, this
solution is rather costly:

- Constructing from a regular list requires traversing the entire list
  (which may be negligible because we assume that, in general, we will
  start from an empty list and progressively accumulate elements, as
  is often done in recursive algorithms that work with lists).<br
  /><br />

- A more annoying problem: we have to traverse the entire list
  regardless in order to produce a regular list. This means that to
  convert an `ord`-tagged list into a regular list, we traverse the
  list once, while converting a `rev`-tagged list into a regular list
  requires traversing it once, then reversing it, resulting in another
  traversal.

I would add another point of friction: this solution requires
rewriting the list API, and even though it seems to (awkwardly) fulfil
its promises in terms of type-level tracking, it doesn't seem to be a
viable solution for a project of reasonable scope. Still, it was a fun
approach (constraining things through the constructors of a data
structure) that, in less performance-critical cases, could be
interesting and useful.

Let's look at the proposal I actually gave: an approach with less
machinery, and probably less exciting, but which, from my perspective,
holds more promise.

### A second _constraint-based_ approach

This detour into defining a new type using GADTs has nevertheless
given us some intuition that the constructors of a list, and its API,
can enforce constraints to maintain reversal. Inspired by this first
approach, we can easily use a **constraint-based** approach to
maintain a similar set of guarantees without having to rewrite the
type of our list, using a [phantom witness][phantom].

This time, since we will impose fewer constraints at the constructor
level (made possible by the use of GADTs), we will start by describing
our interface. As before, we begin by describing our tags:

```ocaml
type rev = [ `Rev ]
type ord = [ `Ord ]
```

This time, we use [polymorphic
variants](https://ocaml.org/manual/5.5/polyvariant.html) for a reason
that we will see shortly afterwards. We can now describe our list type
that maintains its _reversal_:

```ocaml
type ('ord, 'a) olist =
    private 'a list
    constraint 'ord = [< `Rev | `Ord ]
```

We describe a *private alias* for a list, ensuring that we cannot
construct an `olist` manually. We then add a constraint on the `'ord`
type parameter to ensure that it must be an instance of `[< `Rev |
`Ord ]`, which will serve as our tag. This is why our tags are
described using polymorphic variants: it becomes possible to describe
a type that is the union (a closed one, in this case) of `rev` and
`ord`.


<div class="hidden-block">

```ocaml
include Olist
```

</div>

Now we can describe the set of operations that we would like to have.
As before, we want `empty` and `rev_empty`:

<!-- $MDX skip -->
```ocaml
val empty : (ord, 'a) olist
val rev_empty : (rev, 'a) olist
```

Next, we can define the `cons` function, which only operates on
reversed lists (just as in our GADT example), and we can easily
imagine an `append` function:


<!-- $MDX skip -->
```ocaml
val cons : 'a -> (rev, 'a) olist -> (rev, 'a) olist
val append : (ord, 'a) olist -> (ord, 'a) olist -> (ord, 'a) olist
```

As in our previous example, when we enforce the fact that a list built
using `cons` is a reversed list, `cons` takes a value and a reversed
list, and produces a reversed list. `append` enforces the opposite: we
combine two `ord` lists.

We could also trivially imagine `rev_append`, with more meaningful
information in its type (which, from my point of view, is much easier
to read because we don't have to rely on the documentation to know
which list will be reversed: it is the first one):

<!-- $MDX skip -->
```ocaml
val rev_append : (rev, 'a) olist -> (ord, 'a) olist -> (ord, 'a) olist
```

We can then easily imagine the constraints on `of_list` and
`of_rev_list`, the latter simply tagging lists:

<!-- $MDX skip -->
```ocaml
val of_list : 'a list -> (ord, 'a) olist
val of_rev_list : 'a list -> (rev, 'a) olist
```

And the functions for reversing the nature of the list: `rev` and
`ord`:

<!-- $MDX skip -->
```ocaml
val ord : (rev, 'a) olist -> (ord, 'a) olist
val rev : 'a list -> (rev, 'a) olist
```

As before, we also have functions that preserve the _reversal_ of
their input, such as `map`, whose type is fairly straightforward to
write:

<!-- $MDX skip -->
```ocaml
val map : ('a -> 'b) -> ('k, 'a) olist -> ('k, 'b) olist
```

Now that we have an API (as complete as the previous one), we can move
on to the implementation, which is **much simpler than the previous
one**. First, we start by describing our type (removing the private
marker because we want to be able to construct `olist` **within our
module**):

<!-- $MDX skip -->
```ocaml
type rev = [ `Rev ]
type ord = [ `Ord ]
type ('ord, 'a) olist = 
   'a list 
   constraint 'ord = [< rev | ord ]
```

We can now trivially implement our functions, and since the tag is
_just a phantom witness_, we simply call existing functions:

<!-- $MDX skip -->
```ocaml
let empty = []
let rev_empty = []

let cons x xs = x :: xs 
let append xs ys = xs @ ys
let rev_append a b = List.rev_append a b

let of_list x = x 
let of_rev_list x = x

let ord x = List.rev x 
let rev x = List.rev x

let map f x = List.map f x
```

And exactly as before, we can implement our `my_map` function fairly
easily. It does not perform the final `rev`, and this is reflected in
its type:

```ocaml
# let my_map f list =
    let rec aux acc = function 
      | List.[] -> acc 
      | List.(x :: xs) -> aux (cons (f x) acc) xs
    in aux rev_empty list ;;
val my_map : ('a -> 'b) -> 'a list -> (rev, 'b) olist = <fun>
```

We retain the same guarantees as before. The main difference is that
we use a _less direct_ style: we go through `rev_empty` rather than
`[]`, and through `cons` rather than `::`. However, unlike the GADT
solution, we do not have to reconstruct the list _back and forth_, and
we are overall fully compatible with the existing `List` API.

At this point, I feel (and Antonin shares this view) that we have
sketched out a flexible and functional solution. However, there is one
very slight annoyance: we have separate `rev` and `ord` functions,
even though their implementations are identical. For the sake of
elegance, we might imagine a solution that allows us **not to split
the `rev` operation into two different functions** (even though this
is a fairly small price to pay).


### A third approach using _type-level_ switches

The last solution I am going to present is entirely based on the
previous one, with a slight change to the types, allowing us to unify
the `rev` function which, when given a list tagged `rev`, returns a
list tagged `ord`, and _vice versa_.

```diff
- type rev = [ `Rev ]
- type ord = [ `Ord ]
+ type (_, _) dir
+ type ord = ([ `Ord ], [ `Rev ]) dir
+ type rev = ([ `Rev ], [ `Ord ]) dir

 type ('ord, 'a) olist = 
    private 'a list 
-   constraint 'ord = [< rev | ord ]
+   constraint 'ord = (_, _) dir

(* ... *)

- val rev : (ord, 'a) olist -> (rev, 'a) olist
- val ord : (rev, 'a) olist -> (ord, 'a) olist
+ val rev : (('o, 'r) dir, 'a) olist -> (('r, 'o) dir, 'a) olist
```

As we can see, we expose two type parameters in `dir`, and encode the
fact that the reversal of `('a, 'b) dir` is `('b, 'a) dir`, allowing
us to capture the relationship between `ord` and `rev` at the _type
level_.

And in our implementation (the `ml` file), we can simply describe our
`dir` type this way, **since it will never be inhabited**:

<!-- $MDX skip -->
```ocaml
type (_, _) dir = |
```

<div class="hidden-block">

```ocaml
include Tlist
```

</div>

And as with our previous examples, here is our `my_map` function,
which does not perform the final reversal:

```ocaml
# let my_map f list =
    let rec aux acc = function 
      | List.[] -> acc 
      | List.(x :: xs) -> aux (cons (f x) acc) xs
    in aux rev_empty list ;;
val my_map : ('a -> 'b) -> 'a list -> (rev, 'b) olist = <fun>
```

At this point, I think that, provided we consider this invariant
important enough to track, we have achieved our goals, namely:

- We can track the reversal of a list at the type level.
- We can handle `rev` uniformly by using _type-level switches_.

In the [original discussion][nel-issue], [Florian
Angeletti][octachron] (and yes, we had invoked some _Type Wizards_)
proposed an encoding of _type-level_ switches that takes advantage of
objects:

```ocaml
module type S = sig
  type yes = Yes 
  type no = No

  type ord = <neg: rev; ord:yes >
  and rev = <neg:ord; ord:no >

  type ('order,'a) t

  val rev: (<neg:'n; ..>, 'a) t -> ('n,'a) t
end
```

Which pointed out that the direction (`dir`) should not be an
additional parameter to the `rev` function. I think his proposal
(which made my previous implementation possible in the first place) is
roughly equivalent, while, from my point of view, requiring a little
more intellectual gymnastics. It also points out that an object type is
a _type-level record_, and here, unifying against `< neg : 'n ; .. >`
projects a field out of it. That's a type-level function, computed by
the type checker.

## To conclude

This was a very enjoyable little journey. I would really like to thank
[Antonin][misterda] for starting this conversation (even though the
repository may not have been the most appropriate place for it, I'm
glad he took the initiative) and [Florian][octachron], who, once
again, is incredibly impressive in his knowledge of encodings in
OCaml's type system!

I'll finish by throwing a few questions out there! What about you?

- Do you think this kind of invariant is important enough to track in
  the _type system_?
- Do you know of other encodings for this kind of indexing?
- Has this topic already been explored in the literature?
- Would we want to expose a library to address this problem?
- And for those coming from other languages such as
  [Haskell](https://www.haskell.org/),
  [Scala](https://www.scala-lang.org/), [F#](https://fsharp.org/), and
  other languages with richer type systems such as
  [Rocq](https://rocq-prover.org/), [Lean](https://lean-lang.org/),
  [Idris](https://idris-lang.org/), and all the others, how do they
  deal with this kind of problem?

Feel free to reach out to me at
[grm@functional.cafe](https://functional.cafe/@grm). I hope you found
this short, somewhat naive article interesting, and, hopefully, see
you in less than a year for another one.
