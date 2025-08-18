---
title: Basic dependency injection with objects
date: 2025-08-18
description:
  A simple way to encode dependency injection using the Reader monad 
  and objects in OCaml (to work well with type inference).
referenced_humans:
  - [xvw, https://xvw.lol]
  - [jwinandy, https://x.com/ahoy_jon]
bib:
  - ident: xvw-ocaml
    title: "Why I chose OCaml as my primary language"
    authors: [Xavier Van de Woestyne]
    url: https://xvw.lol/en/articles/why-ocaml.html
  - ident: Kyo
    title: "Kyo: Toolkit for Scala Development"
    url: https://getkyo.io/
    authors: [Flavio Brasil, and contributors]
  - ident: freer
    title: "Free and Freer Monads: Putting Monads Back into Closet"
    url: https://okmij.org/ftp/Computation/free-monad.html
    authors: [Oleg Kiselyov]
  - ident: object-layer
    url: https://caml.inria.fr/pub/docs/u3-ocaml/ocaml-objects.html
    title: "Using, Understanding, and Unraveling The OCaml Language: The object layer"
    authors: [Didier Remy]
  - ident: poly-error
    title: "Composable Error Handling"
    url: https://keleshev.com/composable-error-handling-in-ocaml
    authors: [Vladimir Keleshev]
  - ident: boring-haskell
    title: "Boring Haskell Manifesto"
    url: https://www.snoyman.com/blog/2019/11/boring-haskell-manifesto/
    authors: [Michael Snoyman]
---

In his article [_Why I chose OCaml as my primary
language_](https://xvw.lol/en/articles/why-ocaml.html), my friend
[Xavier Van de Woestyne][xvw] presents, in the section [_Dependency
injection and
inversion_](https://xvw.lol/en/articles/why-ocaml.html#dependency-injection-and-inversion),
two approaches to implementing dependency injection: one using
[user-defined
effects](https://xvw.lol/en/articles/why-ocaml.html#through-user-defined-effects)
and one using [modules as first-class
values](https://xvw.lol/en/articles/why-ocaml.html#through-modules). Even
though I’m quite convinced that both approaches are _legit_, I find
them sometimes a bit _overkill_ and showing fairly obvious pitfalls
when applied to real software. The goal of this article is therefore
to briefly highlight the ergonomic weaknesses of both approaches, and
then propose a new encoding of inversion and dependency injection that
I find more comfortable (_in many cases_). In addition, **this gives
an example of using objects in OCaml**, which are often overlooked,
even though in my view OCaml’s object model is very interesting and
offers a lot of practical convenience.

> This approach is by no means novel and is largely the result of
> several experiments shared with [Xavier Van de Woestyne][xvw] during
> multiple _pair-programming_ sessions. However, a precursor of this
> encoding can be found in the [first version of
> YOCaml](https://github.com/xhtmlboi/yocaml/blob/ec0fa3efa1537f90f24f07b77e4d2aaec23ae9d1/lib/yocaml/effect.ml#L3)
> (using a [Left Kan Extension/Freer
> Monad](https://okmij.org/ftp/Haskell/extensible/more.pdf) rather
> than a Reader). It's also interesting we can find a similar approach
> in the recent work around [Kyo](https://github.com/getkyo/kyo), an
> effect system for the [Scala](https://www.scala-lang.org/) language,
> which uses a similar _trick_ based on subtyping relationships to
> type an environment.


## Why use dependency injection?

There are plenty of documents that describe (sometimes a bit
_aggressively_) all the benefits of dependency injection, which are
sometimes extended into fairly formalized software architectures (such
as [hexagonal
architecture](https://en.wikipedia.org/wiki/Hexagonal_architecture_(software))). For
my part, I find that dependency injection makes **unit testing a
program trivial**, which I think is reason enough to care about it
(For example, the _time-tracker_ I use at work,
[Kohai](https://github.com/xvw/kohai), uses
[Emacs](https://www.gnu.org/software/emacs/) as its interface and the
file system as its database. Thanks to inversion and dependency
injection, we were able to [achieve high test
coverage](https://github.com/xvw/kohai/blob/main/test/server/logging_procedure_test.ml)
fairly easily).

### Effect system and dependency injection

There are _many different ways_ to describe an effect handler, so in
my view it is difficult to give a precise definition of what an
_Effect system_ is. However, in our modern interpretation, the goal is
more to suspend a computation so it can be interpreted by the runtime
(the famous [IO monad](https://www.haskell.org/tutorial/io.html)), and
an _Effect system_ is often described as a systematic way to separate
the **denotational** description of a program, where propagated
effects are **operational** “_holes_” that are given meaning via a
_handler_, usually providing the ability to **control the program’s
execution flow** (its **continuation**), unlocking the possibility to
describe, for example, [concurrent
programs](https://kcsrk.info/papers/system_effects_feb_18.pdf). In
this article, I focus on dependency injection rather than on building
an effect system because that would be very _pretentious_ (my article
does not address performance or runtime concerns). Similarly to how
exception handling can be seen as a **special case** of effect
propagation and interpretation (where the captured continuation is
never resumed), I also see dependency injection as a **special case**,
this time, where the continuation is always resumed. It’s quite
amusing to see that dependency injection and exception capturing can
be considered two special cases of effect abstraction, differing only
in how the continuation is handled.

## The Drawbacks of Modules and User-Defined Effects

As I mentioned in the introduction, I believe that both approaches
proposed by Xavier are perfectly legitimate. However, after using both
approaches in real-world software, I noticed several small annoyances
that I will try to share with you.

### Using modules

Using modules (through
[functors](https://ocaml.org/manual/5.1/moduleexamples.html#s%3Afunctors)
or by [passing them as
values](https://ocaml.org/manual/5.1/firstclassmodules.html#start-section))
seems to be the ideal approach for this kind of task. However, the
module language in OCaml has a different type system, in which **type
inference is severely limited**. From my point of view, these
limitations can lead to a lot of verbosity whenever I want to imagine
that my dependencies come from multiple different sources. For
example, consider these two signatures:

The first one provides basic manipulation of the file system (very
simple, with no handling of permissions or errors):


```ocaml
module type FS = sig
  val read_file : path:string -> string option
  val write_file : path:string -> content:string -> unit 
end
```

The second one simply allows logging to standard output (also very
basic, without support for log levels):


```ocaml
module type CONSOLE = sig
  val log : string -> unit
end
```

The first way to depend on **both signatures** is to introduce a new
signature that describes their combination:


```ocaml
module type FS_CONSOLE = sig 
  include FS
  include CONSOLE
end

let show_content (module H : FS_CONSOLE) = 
  match H.read_file ~path:"/foo/bar" with
  | None -> H.log "Nothing"
  | Some x -> H.log x
```

Or simply take the dependencies as two separate parameters:

```ocaml
let show_content (module F : FS) (module C : CONSOLE)  = 
  match F.read_file ~path:"/foo/bar" with
  | None -> C.log "Nothing"
  | Some x -> C.log x
```

Indeed, constructing the module on the fly, directly in the function
definition, is not possible. Although very verbose, this expression is
rejected by the compiler:


```ocaml
# let show_content (module H : sig 
        include FS
        include CONSOLE
      end) =
    match H.read_file ~path:"/foo/bar" with
    | None -> H.log "Nothing"
    | Some x -> H.log x ;;
Lines 1-4, characters 30-10:
Error: Syntax error: invalid package type: only module type identifier and with type constraints are supported
```

Moreover, beyond the syntactic heaviness, I find the loss of type
inference quite restrictive. While in situations where you don’t need
to separate and diversify dependency types this isn’t a big deal, I
find that this approach sometimes forces unnecessary groupings. I
often ended up in situations where, for all functions that had
dependencies, I had to provide a single module containing them all,
which occasionally forced me, in testing scenarios, to create _dummy_
functions. A very frustrating experience!

### Using User-Defined-Effects

I proudly claimed that dependency injection is a special case of using
an _Effect System_, so one might wonder: could using OCaml’s effect
system be a good idea? From my understanding, the integration of
effects was primarily intended to describe interactions with OCaml’s
new multi-core runtime. In practice, the lack of a type system
tracking effects makes, in my view, their use for dependency injection
rather cumbersome. Indeed, without a type system, it becomes, once
again in my view, difficult to mentally keep track of which effects
have been properly handled. In
[YOCaml](https://github.com/xhtmlboi/yocaml), we recorded effects in a
module called
[Eff](https://github.com/xhtmlboi/yocaml/blob/main/lib/core/eff.mli)
that encodes programs capable of propagating effects in a monad (a
kind of IO monad). This allows us to handle programs _a posteriori_
(and thus inject dependencies, of course) but restricts us in terms of
handler modularity. Indeed, it assumes that in **all cases, all
effects will be interpreted**. And, in the specific case of YOCaml, we
usually only want to either continue the program or discard the
continuation (which can be done trivially using an
exception). Control-flow management is therefore a very powerful tool,
for which we have very little use.

In practice, there are scenarios where using OCaml’s effects seems
perfectly legitimate (and I think I have fairly clear ideas about why
introducing a type system for effects is far from trivial,
particularly in terms of user experience):

- When you want to perform backtracking
- When you want to express concurrency libraries, schedulers, etc.,
  which makes a lot of sense in libraries like
  [Eio](https://github.com/ocaml-multicore/eio),
  [Miou](https://github.com/robur-coop/miou), or
  [Picos](https://github.com/ocaml-multicore/picos)

So, in the specific case of dependency injection, I have the intuition
that using OCaml’s effects **gives too much power**, while putting
significant pressure on tracking effects without compiler assistance,
making them not entirely suitable.

## Using objects

It’s not very original to use objects to encode a pattern typically
associated with object-oriented programming. However, in functional
programming, it’s quite common to encounter encodings of dependency
injection sometimes referred to as [_Functional Core, Imperative
Shell_](https://www.destroyallsoftware.com/screencasts/catalog/functional-core-imperative-shell). Although
relatively little used and sometimes unfairly criticized, OCaml’s
object model is actually very pleasant to work with (its theoretical
foundation is even extensively praised in [Xavier’s
article](https://xvw.lol/en/articles/why-ocaml.html#closely-related-to-research),
in the section _Closely related to research_). To my knowledge, OCaml
is one of the rare _mainstream languages_ that draws a very clear
separation between **objects**, **classes**, and **types**. Objects
are _values_, classes are _definitions for constructing objects_, and
objects have _object types_, which are regular types, whereas classes
also have types that are not regular, since classes are not regular
expressions but rather expressions of a small class language.

In order to integrate coherently into OCaml and with type inference,
the object model relies on four ingredients: **structural object
types** (object types are structural, their structure is transparent),
**row variables**, **equi-recursive types**, and **type
abbreviations**.

> In practice, an object type is made up of **the row of visible
> members** (associated with their types) and may end with a **row
> variable** (to characterize closed/open object types). This row
> variable can serve as the subject of unification as objects are used
> together with their types.

A quick way to become aware of the presence of the row variable is to
simply write a function that takes an object as an argument and sends
it a message (in OCaml, sending a message is written with the syntax
`obj # message`):

```ocaml
# let f obj = (obj # foo) + 10 ;;
val f : < foo : int; .. > -> int = <fun>
```

In the return type, the row variable indicating that the object type
is open is represented by `<..>`. It is thanks to this variable that we
can perform dependency injection, finely tracked by the type system
and guided by inference.

### Simple example

To keep things simple, let’s just revisit the classic _teletype_
example, which we could write in _direct style_ like this:

```ocaml
# let teletype_example () = 
    print_endline "Hello, World!";
    print_endline "What is your name?";
    let name = read_line () in 
    print_endline ("Hello " ^ name)
val teletype_example : unit -> unit = <fun>
```

Let’s rewrite our example by taking an object as an argument, which
will serve as the handler:

```ocaml
# let teletype_example handler = 
    handler#print_endline "Hello, World";
    handler#print_endline "What is your name?";
    let name = handler#read_line () in
    handler#print_endline ("Hello " ^ name)
val teletype_example :
  < print_endline : string -> 'a; read_line : unit -> string; .. > -> 'a =
  <fun>
```

To convince ourselves of the compositionality of our dependency
injection, let’s imagine the following function, whose role is to
simply _log_ traces of the execution:

```ocaml
# let log handler ~level message = 
    handler#do_log level message
val log : < do_log : 'a -> 'b -> 'c; .. > -> level:'a -> 'b -> 'c = <fun>
```

By using the `teletype_example` and `log` functions, we can directly
observe the precision of the elision, showing that our `handler`
object was open each time:

```ocaml
# let using_both handler = 
    let () = log handler ~level:"debug" "Start teletype example" in
    teletype_example handler
val using_both :
  < do_log : string -> string -> unit; print_endline : string -> 'a;
    read_line : unit -> string; .. > ->
  'a = <fun>
```

All the requirements of our `using_both` function are (logically)
correctly tracked. We can now implement a _dummy_ handler very simply, using
immediate object syntax:

```ocaml
# using_both object
    method do_log level message = 
      print_endline ("[" ^ level ^ "] " ^ message)

    method print_endline value = print_endline value
    method read_line () = 
      (* Here I should read the line but hey, 
        it is not interactive, let's just return my name. *)
      "Pierre"
  end;;
[debug] Start teletype example
Hello, World
What is your name?
Hello Pierre

- : unit = ()
```

This approach is extremely similar to using [polymorphic
variants](https://ocaml.org/manual/5.3/polyvariant.html) for
[composable error
handling](https://keleshev.com/composable-error-handling-in-ocaml),
which share many features with objects (structural subtyping, rows).

## Typing, sealing and reusing

In our examples, we were guided by type inference. However, in OCaml,
it is common to restrict the generality of inference using explicit
signatures. As we have seen, some of our inferred signatures are too
general and arguably not very pleasant to write:

```
  < do_log : string -> string -> unit; 
    print_endline : string -> 'a;
    read_line : unit -> string; 
    .. 
  >
```

Fortunately, type abbreviations allow us to simplify this notation. By
using [class
types](https://ocaml.org/manual/5.3/classes.html#ss%3Aclasstype) and
certain abbreviations, we can simplify the type expressions of our
functions that require injection:

First, we will describe our types using dedicated class types, let's
start with `console`:


```ocaml
class type console = object
  method print_endline : string -> unit
  method read_line : unit -> string
end
```

Now let's write our `loggable` interface:

```ocaml
class type loggable = object
  method do_log : level:string -> string -> unit
end
```

Now, let's rewrite our three functions inside a submodule (to make
their signatures explicit):

```ocaml
module F : sig 
  val teletype_example : #console -> unit
  val log : #loggable -> level:string -> string -> unit
end = struct

  let teletype_example handler = 
    handler#print_endline "Hello, World";
    handler#print_endline "What is your name?";
    let name = handler#read_line () in
    handler#print_endline ("Hello " ^ name)
    
  let log handler ~level message = 
    handler#do_log ~level message
end
```

And now, we can describe our `using_both` function as taking an object
that is the conjunction of `loggable` and `console`, like this:



```ocaml
module G : sig 
  val using_both : <console; loggable; ..> -> unit
end = struct
  let using_both handler = 
    let () = F.log handler ~level:"debug" "Start teletype example" in
    F.teletype_example handler
end
```

At the implementation level, the separation between inheritance (as a
syntactic action) and subtyping (as a semantic action) allows us to
benefit from this kind of mutualization directly at the _call
site_. For example, let's implement a handler for `console` and
`loggable`:

```ocaml
class a_console = object
  method print_endline value = print_endline value
  method read_line () = 
    (* Here I should read the line but hey, 
       it is not interactive, let's just return my name. *)
    "Pierre"
end

class a_logger = object
  method do_log ~level message = 
    print_endline ("[" ^ level ^ "] " ^ message)
end
```

Even though it would be possible to constrain our classes by the
interfaces they implement (using `class x = object (_ :
#interface_)`), it is not necessary because **structural subtyping will
handle the rest** (and it also allows us to potentially introduce
intermediate states easily). We can now **use inheritance to share
functionality** between our two handlers:

```ocaml
# G.using_both object
    inherit a_console
    inherit a_logger
  end ;;
[debug] Start teletype example
Hello, World
What is your name?
Hello Pierre

- : unit = ()
```

One could argue that it’s still a bit verbose, but in my view, this
approach offers **much** more convenience. We know **statically** the
capabilities that need to be implemented, we retain type inference,
and we have very simple composition tools. At this point, I have,
_subjectively_, identified scenarios for using the different
approaches discussed in this article:

- When you need to control the program’s continuation (essentially for
  backtracking or concurrency), it’s preferable to use effects (hoping
  that one day we’ll be able to type them ergonomically).

- When you want to introduce types (without parametric polymorphism)
  into dependencies, *first-class modules* work very well.
  
- When you want to introduce types that can have type parameters (for
  example, to express the normal forms of our dependencies via a
  runtime value, e.g., through a monad),
  [functors](https://ocaml.org/manual/5.3/moduleexamples.html#s%3Afunctors)
  are suitable.

- When you want to do **simple dependency injection**, guided by type
  inference and requiring the ability to fragment or share handlers,
  objects are perfectly suitable.

However, the approach based on first-class modules or objects can
**heavily pollute a codebase**, whereas effect interpretation and
functor instantiation can remain at the edges of the program. Let’s
look at the final part of this article, which explains how to reduce
the aggressive propagation of handlers.

## Injected dependencies as part of the environment

Currently, our approach forces us to pass our handler explicitly from
call to call, which can drastically bloat business logic code. What we
would like is **the ability to only worry about the presence of
dependencies when it is actually necessary**. To achieve this, we’ll
use a module whose role will be to pass our set of dependencies in an
*ad-hoc* manner:

```ocaml
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
```

Our module allows us to separate the description of our program from
the passing of the environment. The only subtlety lies in the `(let*)`
operator, a [*binding
operator*](https://ocaml.org/manual/5.3/bindingops.html) that lets us
simplify the writing of programs. Let's define some helpers based on
our previous interfaces:

```ocaml
module U : sig 
  val print_endline : string -> (unit, #console) Env.t
  val read_line : unit -> (string, #console) Env.t
  val log : level:string -> string -> (unit, #loggable) Env.t
end = struct 
  let print_endline str = 
    Env.perform (fun h -> h#print_endline str)
  
  let read_line () = 
    Env.perform (fun h -> h#read_line ())
  
  let log ~level message = 
    Env.perform (fun h -> h#do_log ~level message)
end
```

And now, we can describe our previous programs using our `let*` syntax
shortcut:

```ocaml
let comp = 
  let open Env in 
  let* () = U.log ~level:"Debug" "Start teletype example" in
  let* () = U.print_endline "Hello, World!" in 
  let* () = U.print_endline "What is your name?" in 
  let* name = U.read_line () in 
  U.print_endline ("Hello " ^ name)
```

And we can handle it using `Env.run`:

```ocaml
# Env.run object 
    inherit a_console
    inherit a_logger
  end comp ;;
[Debug] Start teletype example
Hello, World!
What is your name?
Hello Pierre

- : unit = ()
```

Some prefer to pass handlers explicitly to avoid relying on binding
operators. Personally, I really like that the operators make it
explicit whether I’m dealing with a pure expression or one that
requires dependencies, and I find that binding operators make the code
readable and easy to reason about.


## Under the hood

Looking at the signature of the `Env` module, many will notice that it
is a [Reader
Monad](https://hackage.haskell.org/package/mtl-2.3.1/docs/Control-Monad-Reader.html)
(a specialization of `ReaderT` transformed with the `Identity` monad),
which is sometimes also called a `Kleisli`. In practice, this allows
us to be parametric over the normal form of our expressions. For
simplicity in the examples, I’ve minimized indirection, but it is
entirely possible to project our results into a more refined monad,
defining a richer runtime (and potentially supporting continuation
control, effect interleaving, etc.).

## To conclude

Some might be surprised—indeed, I’ve fairly closely applied the
[*Boring
Haskell*](https://www.snoyman.com/blog/2019/11/boring-haskell-manifesto/)
philosophy. I literally used objects for dependency injection (the
**extra-classical approach** to DI) and rely on a `ReaderT` to access
my environment on demand, which is a **very common approach** in the
Haskell community.

The only idea here, **which isn’t particularly novel**, is to use
subtyping relationships to statically track the required dependencies,
and rely on inheritance to arbitrarily compose handlers. From my point
of view, this drastically reduces the need to stack transformers while
still keeping modularity and extensibility. By relying on a different
normal form than the identity monad, it’s possible to achieve results
that are surprisingly pleasant to use and *safe*, as demonstrated by
[Kyo](https://getkyo.io/) in the Scala world. In OCaml, the richness
of the object model (and its structural capabilities) is a real
advantage for this kind of encoding, allowing a drastic reduction of
the boilerplate needed to manage multiple sets of dependencies.

In practice, I’ve found this approach effective for both personal and
professional projects (and, importantly, very easy to explain). One
limitation is the inability to eliminate dependencies when they are
partially interpreted in ways other than by partial function
application. Still, the encoding remains neat for at least three
reasons:

- It allows us to statically track dependencies in the context of
  dependency injection.
- It makes it easy to write testable programs by providing handlers
  adapted for unit tests.
- It provides another example showing that OCaml’s objects are really
  powerful and can offer fun solutions to well-worn problems.

In the not-so-distant future, we might even imagine providing handlers
more lightly using [Modular
Implicits](https://www.cl.cam.ac.uk/~jdy22/papers/modular-implicits.pdf).

Thank you for reading (if you made it this far), and a special thanks
to [Xavier Van de Woestyne][xvw] for his article that inspired me to
write this one, and to [Jonathan Winandy][jwinandy] for showing me
Kyo and helping me rephrase some sentences.
