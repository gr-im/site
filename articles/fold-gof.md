---
title: Fold for cheap pattern-matching
date: 2024-03-18
description: 
  Summary of a response regarding the encoding of visitors without 
  pattern matching in OCaml, using the fold function.
  
referenced_people:
  - [hakimba, https://hakimba.github.io/oxywa/]
  - [xvw, https://xvw.lol]
  
bib:
  - ident: gof
    title: "Design Patterns: Elements of Reusable Object-Oriented Software"
    year: 1994
    authors: [Erich Gamma, Richard Helm, Ralph Johnson, John Vlissides]
    url: https://en.wikipedia.org/wiki/Design_Patterns
  - ident: rec-scheme
    title: Functional programming with bananas, lenses, envelopes and barbed wire
    year: 1991
    authors: [Erik Meijer, Maarten Fokkinga, Ross Paterson]
    url: https://maartenfokkinga.github.io/utwente/mmf91m.pdf
  - ident: fold
    title: A tutorial on the universality and expressiveness of fold
    year: 1999
    authors: [Graham Hutton]
    url: https://www.cs.nott.ac.uk/~pszgmh/fold.pdf
---

A few days ago, [Hakim Baaloudj][hakimba] reacted to a somewhat provocative
message from [Xavier Van de Woestyne][xvw], stating that all design patterns
proposed in the book "_Design Patterns: Elements of Reusable Object-Oriented
Software_" could be reduced to "_if only my language had lambdas and modules_".
This led him to ask the following question in a conversation space that we all
frequent:

> "_And one of the first thoughts I had was that we'd also need **pattern
> matching** (especially for the **visitor design pattern**), how can we avoid
> having to use the visitor's encoding, just by using modules and lambdas?_"

I don't have a particular opinion on the book (or on design patterns in
general), but here is a revised version of the response I sent to him. The
article is obviously not groundbreaking, and it simply sketches out the encoding
of visitors through `fold`. Moreover, it should only be taken as a response to
the question "_how to encode the visitor without pattern matching_" and not as a
plea against the usefulness of pattern matching. Indeed, I am instinctively
convinced that, akin to the explicit ability to delineate algebraic types,
pattern matching objectively enhances a language.

## The main idea behind the `fold` function

We can offer an exceedingly broad definition of the `fold` function, which
aligns with the domain of **recursion schemes** (referred to as a
_catamorphism_), extensively expounded upon in [this paper][rec-scheme],
encapsulating the concept of generic reduction. However, I believe that, for the
purposes of demonstration, delving into extensive theory is unnecessary. It
suffices to describe, in the case of the _catamorphism_, a **case analysis**.
Indeed, one could summarise the `fold` function as one that will **traverse**
the various branches of a type. Let's consider an initial example with the
option type, described by the following type:

```ocaml
type 'a option = 
  | Some of 'a
  | None
```

The `fold` function will need to handle the case where the value is `Some x` or
if the value is `None`. Nothing could be simpler, _old chap_! We shall describe
a function of type: `'a option -> ('a -> 'b) -> (unit -> 'b) -> 'b`.

```ocaml
let fold opt when_some when_none =
  match opt with
  | None   -> when_none ()
  | Some x -> when_some x 
```

So, if our value happens to be `Some x`, we employ `when_some x`, and if it
turns out to be `None`, we utilise `when_none ()` (employing a function `unit ->
'b` to defer computation in the event of `None`). With this function, one can
readily re-encode pattern matching cases (admittedly, at the expense of a bit
more verbosity). For example, this _peculiar function_:

```ocaml
let my_f opt = 
  match opt with
  | Some ((3 | 10) as x) -> x
  | Some x -> 0 - x
  | None -> 0
```

Could possibly be rewritten in terms of fold in this manner:

```ocaml
let my_f_with_fold opt = fold opt
  (fun x  -> 
     if (x = 3 || x = 10) then x else 0 - x)
  (fun () -> 0)
```

In terms of outcome, the two functions are identical. However, while the
approach with `fold` is, let's be honest, considerably more verbose than the one
using pattern matching, but `fold` can also operate on **abstract types** (types
whose structure/shape is unknown, or solely _crystallised through its API_).
`fold` is indeed **highly generalisable** and it's a fascinating exercise to
implement it for a plethora of sum types (also introducing recursion, such as
`List` or for trees), and alongside recursion schemes, its properties are
expansively documented in [this paper][fold].

However, more astute readers may have noticed a **slight trickery**! Indeed,
**we use pattern matching to suggest that we can do without pattern matching**,
which seems rather bold! No worries, let's reimplement `Option` in terms of
objects and completely do away with pattern matching.

## Objects and absence of pattern matching

Since [OCaml](https://ocaml.org) boasts a perfectly decent object-oriented
language, we don't need to switch languages, which is rather splendid. Firstly,
let's describe the interface of our option using an _OOP_ interface:

```ocaml
class type ['a] option_obj = object
  method fold : ('a -> 'b) -> (unit -> 'b) -> 'b
end
```

Now, we shall implement the constructors `some` and `none` so that they adhere
to this interface:

```ocaml
module Option_obj : sig
  val some : 'a   -> 'a option_obj
  val none : unit -> 'a option_obj 
  val fold : 'a option_obj -> ('a -> 'b) -> (unit -> 'b) -> 'b
end
```

The major difference with the constructors `Some` and `None` lies in the fact
that `none` must take `unit` as an argument, due to the [_value
restriction_](https://v2.ocaml.org/manual/polymorphism.html), but this is a
detail that doesn't make its usage overly complex. Now, we can implement the
structure of the module `Option_obj`, which, in fact, is conceptually **very
close** to what we had done with pattern matching.

```ocaml
module Option_obj = struct 
  
  class ['a] some (x: 'a) = 
    object (_: 'a #option_obj)
      method fold when_some _when_none = when_some x
    end
  
  class ['a] none = 
    object (_: 'a #option_obj)
      method fold _when_some when_none = when_none ()
    end
    
  let fold (opt : 'a option_obj) when_some when_none = 
    opt#fold when_some when_none
  
  let some x = new some x
  let none () = new none
end
```

One can observe the natural symmetry between disjunctions via sum types and
through subtyping relations. Our `fold` function (in the `Option_obj` module)
has the same API as the one we defined using pattern matching, but this time,
we're not using pattern matching at all!

The **major** difference from the usual definition of a visitor is that when we
support lambdas, we can drastically **reduce the need for boilerplate** to add
behaviour to our case analysis. Indeed, without lambdas, for each case analysis,
we would need to add an interface unifying both cases through an interface (and
thus concretize it with an implementation).

## So, do we truly need pattern matching

We've seen that it's possible to do without pattern matching using subtyping
relations and the presence of lambdas significantly simplifies the definition of
visitors. However, something about the premise bothers me a bit. Indeed, we're
using an **encoding** to build a missing feature of the language: pattern
matching. But, just as we can encode _cheap_ pattern matching, **we can encode**
_cheap_ lambdas via objects:

```ocaml
class type ['a, 'b] lam = object
  method apply : 'a -> 'b
end
```

Allowing us to entirely sidestep lambdas by redefining our type `'a option_obj`
in this fashion:

```ocaml
class type ['a] option_obj = object
  method fold : ('a, 'b) lam -> (unit, 'b) lam -> 'b
end
```

Enabling us, albeit with a considerable verbosity, to have visitors without
lambdas and without the need for visitor unification. But who would want to
write that? Especially in OCaml?

## Conclusion

I perfectly understand that the support for lambdas in a language significantly
**reduces the necessity for complicated encodings**, which rely on complex
inheritance lattices, on many aspects. However, we have also seen that it is
possible to encode lambdas in a similar manner to how we have used for pattern
matching, prompting me to ask the following question: "_if we can encode
lambdas, in what way is pattern matching less necessary than lambdas_"?

My conclusion is therefore a bit more extreme than [Xavier][xvw]'s, considering
that any functionality, comprehensible, which makes syntactical sense, deserves
to be added to a language, and that as fulfilled OCaml programmers, we should
not impose [Church encodings](https://en.wikipedia.org/wiki/Church_encoding) on
ourselves when our language offers us interesting syntactic constructions!
However, understanding these encodings (and their generalizations, i.e.,
recursion schemes) sometimes allows for building generic intuitions and
sometimes for supporting features when the language grammar does not offer
first-class support, a bit like profunctors, which impose point-free style but
allow for handling "_kinds of functions_" generically.
