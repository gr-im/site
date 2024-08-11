---
title: Sorting things, rank-aggregation (beginner's approach)
date: 2024-08-10
description:
  Summary of a response about how to order products by their votes/reviews using 
  rank aggregation (using Shopify approach).
referenced_humans:
  - [xvw, https://xvw.lol]
bib:
  - ident: bmfh
    title: "Bayesian Methods for Hackers: Probabilistic Programming and Bayesian Inference"
    year: 2015
    authors: [Cameron Davidson-Pilon]
    url: https://www.oreilly.com/library/view/bayesian-methods-for/9780133902914/
  - ident: wilson
    title: "Binomial proportion confidence interval"
    url: https://en.wikipedia.org/wiki/Binomial_proportion_confidence_interval
    authors: [Wikipedia]
  - ident: reddit-comment
    title: "Reddit's new comment sorting system"
    url: http://web.archive.org/web/20140307091023/http://www.redditblog.com/2009/10/reddits-new-comment-sorting-system.html
    authors: [Randall Munroe]
  - ident: reddit-formula
    title: Deriving the Reddit Formula
    url: https://www.evanmiller.org/deriving-the-reddit-formula.html
    authors: [Evan Miller]
  - ident: not-sort-by-avg
    title: How Not To Sort By Average Rating
    url: https://www.evanmiller.org/how-not-to-sort-by-average-rating.html
    authors: [Evan Miller]
  - ident: ranking-star
    title: Ranking Items With Star Ratings
    url: https://www.evanmiller.org/ranking-items-with-star-ratings.html
    authors: [Evan Miller]
---

Last year, a friend of [Xavier Van de Woestyne][xvw] posed a question to him—one
for which he had some inklings but lacked precise answers. Given his
professional commitments, he requested that I provide a succinct response on his
behalf. This article seeks to outline the issue concisely and offer a considered
solution. As with many problems, knowing the name of the problem makes it much
easier to find a solution. The goal of the response I provided (and, by
extension, of this article) was to offer a _simple solution_ that could be
easily integrated into an existing database. For the sake of clarity (and
conciseness) in the article, **performance considerations are not taken into
account**.

<div class="hidden-block">

```ocaml
# open Article_lib.Rank_aggregation ;;
# #install_printer pp_set ;;
```

</div>


## Context

Let’s imagine a **list of products** where users can vote using `up` and `down`
options. How might we go about sorting these results in an intelligent manner?
Here is an example of our data source: we have the **name of a product**, an
**amount of voters** and a **result**. The result is the percentage calculated
between the number of positive votes and the number of negative votes :


```ocaml
# dataset ;;
- : data list =

Name		Voters	Result	Upvotes	Downvotes

Product A	  100	32.0	   32	   68
Product B	 1000	89.0	  890	  110
Product C	    2	100.0	    2	    0
Product D	 3000	51.0	 1530	 1470
Product E	  759	69.0	  524	  235
Product F	  590	20.0	  118	  472
Product G	  100	25.0	   25	   75
```

This kind of modelling of data by expressing the popularity of an entry is
fairly common; it's the kind of representation on which the sorting of
[Reddit](https://www.reddit.com/) messages is based, for example.

## Problem sketch

Our exercise is relative. We want to provide a function capable of sorting
products _in a relevant way_. Obviously, it is difficult to give a **systematic
definition of relevance** for any context, but let's look at this example. Let's
say I want to sort products "from most popular to least popular" (in descending
order of popularity). I could very naively sort my products using the `result`,
which is the percentage calculated on the basis of `up/down` votes.


```ocaml
# sort (fun a b -> Float.compare b.result a.result) ;;
- : data list =

Name		Voters	Result	Upvotes	Downvotes

Product C	    2	100.0	    2	    0
Product B	 1000	89.0	  890	  110
Product E	  759	69.0	  524	  235
Product D	 3000	51.0	 1530	 1470
Product A	  100	32.0	   32	   68
Product G	  100	25.0	   25	   75
Product F	  590	20.0	  118	  472
```

We can argue that our result is **objectively good** because the product `C`
which received 100% positive votes is in first position. There are many cases in
which this answer would be acceptable. However, at a time when recommendation
engines are building streams of consumption (like
[Netflix](https://netflix.com), [Spotify](http://spotify.com/), etc.), the
organisation of this kind of vote raises some interesting questions, for
example:

- is `product C` really considered more positively than `product B`
- is `product D` potentially considerer more positively than `product B`

We can arbitrarily consider that in the case of the first question, `product C`
ranks lower than `product B`, which has many more positive votes. On the other
hand, in the second question, even though `product D` has **far more positive
votes**, the large number of negative votes mitigates against its ranking. This
kind of question raises a set of more general questions about the relationship
between upvotes and downvotes and is broadly referred to as **rank aggregation
problems** which is widely documented in the statistical and Bayesian
interpretation literature.

The problem is also extremely well summarized in the introduction of the article
"[_How Not To Sort By Average Rating_][not-sort-by-avg]" by [Evan
Miller](https://www.evanmiller.org/index.html).

### Some bizarre solutions

In drafting his question, [Xavier][xvw] suggested a few avenues, a little
strange, but which illustrate the versatility of the problem (the first proposal
being that using only the percentage). All the solutions relied on changes in
weighting and didn’t lead to results that one might _instinctively_ consider
valid. However, I would like to share with you his latest proposal, which I
found quite _original_.

Firstly, weighting _slices_ are defined. The idea is to allow you to use the
percentage only if you are in the same slice. 

```ocaml
let slice_of data = 
  let p = result data |> Float.to_int in
  if p = 100 then 8 else p / 9
```

We assume that if we have a perfect score (`100`), we project the result into
the last slice, `9`, so that the score can be compared with the results between
`90` and 100 (_inclusive_). Now we can refine our heuristic so that it only
produces a fine comparison when scores are present in the same slice:

```ocaml
# sort (fun a b -> 
    let slice_a = slice_of a and slice_b = slice_of b in
    if Int.equal slice_a slice_b then
      let a = a.result *. 
        (Float.of_int a.amount_votes *. (a.result /. 100.0))
      and b = b.result *. 
        (Float.of_int b.amount_votes *. (b.result /. 100.0)) in
      Float.compare a b
    else Int.compare slice_b slice_a) ;;
- : data list =

Name		Voters	Result	Upvotes	Downvotes

Product B	 1000	89.0	  890	  110
Product C	    2	100.0	    2	    0
Product E	  759	69.0	  524	  235
Product D	 3000	51.0	 1530	 1470
Product A	  100	32.0	   32	   68
Product G	  100	25.0	   25	   75
Product F	  590	20.0	  118	  472
```

The result seems correct, however, the calculation of the _pivot_ to define the
slices seems a little arbitrary (mainly because this approach is problematic
where there are **strong proximities with the boundaries of a slice**) and it
would be interesting to see what the big ad sites offer.

### Some preliminary conclusions

In the light of our few small experiments, we can quickly draw a number of
interesting pre-conclusions. To avoid products with too many (potentially
negative) votes, i.e. 10,000 positive votes against 20,000 negative votes, we
probably need to weight the positive votes more heavily (in other words,
penalise the negative votes) by means of exponential curves.

In our example of slices, the indexing **gave some exponential
differentiation**, but in a very _ad hoc way_. To break these ad hoc encodings,
I reread certain chapters of the book [Bayesian Methods for Hackers:
Probabilistic Programming and Bayesian Inference][bmfh].

## The Shopify approach

The [book][bmfh] provides an extremely precise answer to a sorting problem based
on reviews used at [Shopify](https://www.shopify.com) (a toolbox offering
advanced functionalities for implementing e-commerce platforms), and here is a
fairly free implementation. Firstly, we define a function to assign a score to
an input (a product). We will then use the comparison of these scores to sort
our dataset.

```ocaml
let shopify_score data = 
  let (total_up, total_down) = up_down data in
  let up = total_up |> succ |> Float.of_int 
  and down = total_down |> succ |> Float.of_int in 
  let total = up +. down in
  let base = up /. total 
  and coef = 1.65 *. sqrt (up *. down /. (Float.pow total 2.0 *. (total +. 1.0))) in
  base -. coef
```

Now we can use our score to order our dataset. As you can see, the result seems
reasonable:

```ocaml
# sort (fun a b -> 
    let a = shopify_score a
    and b = shopify_score b in
    Float.compare b a) ;;
- : data list =

Name		Voters	Result	Upvotes	Downvotes

Product B	 1000	89.0	  890	  110
Product E	  759	69.0	  524	  235
Product D	 3000	51.0	 1530	 1470
Product C	    2	100.0	    2	    0
Product A	  100	32.0	   32	   68
Product G	  100	25.0	   25	   75
Product F	  590	20.0	  118	  472
```

To (_try to_) confirm the relevance of our result, we can slightly modify the number of
positive votes for our `product C', to see how it grows in the list of reviews:

```ocaml
# sort ~dataset:(update "Product C" ~up:20 ~down:0) 
   (fun a b -> 
      let a = shopify_score a
      and b = shopify_score b in
      Float.compare b a) ;; 
- : data list =

Name		Voters	Result	Upvotes	Downvotes

Product C	   20	100.0	   20	    0
Product B	 1000	89.0	  890	  110
Product E	  759	69.0	  524	  235
Product D	 3000	51.0	 1530	 1470
Product A	  100	32.0	   32	   68
Product G	  100	25.0	   25	   75
Product F	  590	20.0	  118	  472
```

From my point of view, which is clearly not that of an expert in "_presenting
ordered data_", I find the results rather convincing, and they provide a good
basis for sorting, which could be altered by taking into account temporal data
(for example) or additional criteria. It's possible to go much further, but if
we take the origin of this response in context, providing a function capable of
ordering product lists according to reviews (up/down vote) taking into account
the _number of votes_, I found this solution to be very useful. One can quickly
fall down the rabbit hole (for example, through the [Binomial proportion
confidence interval][wilson]), discovering increasingly sophisticated sorting
solutions, and one of the challenges of this exercise was to remain concise
while seamlessly integrating with an existing sorting function.

## Conclusion

Sorting data based on reviews is a complex task that likely requires advanced
domain knowledge. For instance, the heuristic would probably differ
significantly if you were ordering products versus posts on a social network
(like [Reddit](https://reddit.com)). However, it's an enjoyable challenge (that
lends itself quite well to _literate programming_).

In fact, before settling on the Shopify approach, I was very intrigued by the
methods used by Reddit to calculate message scores. It’s a fascinating topic
that led me to several interesting resources (for example, [this
article][reddit-comment] describing how comments are sorted, written by the
author of [XKCD](https://xkcd.com/), [Randall
Munroe](https://en.wikipedia.org/wiki/Randall_Munroe)), which I've included in
the bibliography (even though they didn't serve as the basis for this article).

This is the end of this very brief article, which sketches out a somewhat naive
solution to what is potentially a much more complex problem. If you have any
suggestions for _plug and play_ approaches similar to the one I’ve presented,
I’d be delighted to hear them and possibly update this article.
