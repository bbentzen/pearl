# The Pearl documentation

Pearl runs on a variant of computational type theory without a top-level layer of proof refinment logic like NuPRL and its descendents [[2](#NuPRL), [3](#MetaPRL), [4](#RedPRL)], meaning that it is intended as a "window on the truth" with respect to a intended semantics defined independently of a proof system. The philosophy behind this semantics has its most systematic exposition in [[4](#BEN27), §§9–37]. Roughly, the idea is that the terms of a program behave as realizers and not formal proofs in a fixed and necessarily incomplete formal theory. Below you will find a short reference manual on the basics of Pearl. See [[5](#CON09), [4](#BEN27), [6](#STE15)] for some friendly introductions to computatonal type theory.

## The type theory of Pearl

To be more precise, Pearl implements a variant of extensional type theory [[7](#CMCP). Currently, the main difference is that the type theory of Pearl supports user-defined inductive type families and only runs on built-in type formers for dependent functions, the equality type, the empty type, and a cumulative hierarchy of universes à la Russell. 

## Usage

There are a number of commands for inductively defining type families, entering the proof environment, type inference, term evaluation, importing files for the modularizion of proofs, declaring universe levels, and extracting and priting terms from definitions and theorems:

### Inductive environment

The syntax for defining an indexed inductive type is:

```inductive foo : type l
| constructor1 : ... → foo
| constructor2 : ... → foo
...
| constructorn : ... → foo
```

Recursors are automatically generated under the name `foorec`. 

### Proof environment

The proof environment is the main command where definitions are stated and theorems and lemmas are proven. Syntactically speaking, there is no difference between defintitions and theorems and lemmas. Users can use `def`, `definition`, `thm`, `theorem`, `lem`, and `lemma` interchangeably.

```
  def [name-of-theorem] [context] :
   [type] := [term]
```

Contexts are lists of variable declarations. Explicit variables are enclosed with `(` and `)` and must be passed as parameters when the definition or theorem is reused later. Implicit variables are enclosed with curly braces `{` and `}` and can be inferred by the elaborator. Multiple variables of the same type can be declared at the same time.

Types and their terms are determined by Pearl's raw language, which is based on a Curry-style version of the untyped lambda-calculus extended with constants for type formers and their constructors and eliminators (when they exist). To keep the size of the kernel to a minimum, the only built-in types are dependent function type, equality type, empty type, and universe types:

Primitive types | Notation | Constructors | Eliminators
------------ | ------------- | ------------- | -------------
Dependent function type	| Π (x : M), N | λ x , M | M N
Equality type | eq K M N | refl M | 
Empty type | void | | 
Universe type | type n | 

In addition, the user can also have `_` and `?` as placeholders in any expression. The former is used to synthesize an implicit assumption or fail after a number of steps, evaluating and displaying the type of the current goal. The latter is used to display the type of current goal directly without evaluation.

Notice that, as explained in [4](#BEN27), [6](#STE15)], there is no need for eliminators for the equality type or the empty type from the computational point of view, since the semantics justifies general inference rules on the level of judgments. To acommodate this behavior, the language also contains two primitive operations on programs:

- Reflection. This implements the reflection rule, which states that when the equality type is inhabited the two terms are judgmentally equal. When the user types `reflect M N` when proving a theorem and `M` realizes an equality type, the elaborator rewrites `N` and the current goal so that the terms are syntactically identical to each other.

- Explosion. This implements a generalized ex falso rule in which the explosion
takes place not at the level of types but of judgments. When the user types `explode M N` when proving a theorem and `M` realizes the empty type, the elaborator aborts the proof leaving `N` left as its realizer.

### Type inference

The syntax for type inference is:

```
  infer [context] : foo
```

### Evaluation

Pearl does not rely on normalization-by-evaluation. Instead, evaluation is untyped due to philosophical reasons having to do with closer adherence to the meaning explanations of type theory. The syntax for term evaluation is:

```
  eval foo
```

### File import

This command imports a specified file into the current file. The syntax is 

`import [filename]`

### Universe declaration 

This declares a universe level variable according to the syntax 

`universe [id]`

Note that if you are using the VS Code Extension you may type the small script ell `ℓ` with `\ell`.

### Term extraction 

This extracts and prints the realizer corresponding to a definition or theorem with the syntax 

`print [name]`

## References

<a name="NuPRL">[1]</a>
R. L. Constable, S. F. Allen, H. M. Bromley, W. R. Cleaveland, J. F.
Cremer, R. W. Harper, D. J. Howe, T. B. Knoblock, N. P. Mendler,
P. Panangaden, J. T. Sasaki, and S. F Smith. Implementing Mathematics
with The Nuprl Proof Development System. Prentice-Hall, 1986. URL [https://www.nuprl.org/book/](https://www.nuprl.org/book/).

<a name="MetaPRL">[2]</a>
Jason J. Hickey. The MetaPRL Logical Programming Environment. PhD thesis,
Cornell University, Ithaca, NY, January 2001. URL [https://dl.acm.org/doi/book/10.5555/932618](https://dl.acm.org/doi/book/10.5555/932618)

<a name="RedPRL">[3]</a>
Carlo Angiuli, Evan Cavallo, Kuen-Bang Hou (Favonia), Robert Harper, and Jonathan Sterling. The RedPRL Proof Assistant (Invited Paper). In Proceedings of the 13th International Workshop
on Logical Frameworks and Meta-Languages: Theory and Practice, LFMTP@FSCD 2018,
Oxford, UK, 7th July 2018., pages 1–10, 2018. URL: 10.4204/EPTCS.274.1. URL [http://dx.doi.org/10.4204/EPTCS.274.1](http://dx.doi.org/10.4204/EPTCS.274.1).

<a name="BEN27">[4]</a>
Bruno Bentzen. Philosophical type theory. 
Logic, Epistemology, and the Unity of Science, volume 68. Springer, Cham. 202x.
URL [https://link.springer.com/book/9783032419392](https://link.springer.com/book/9783032419392).

<a name="CON09">[5]</a>
Robert L. Constable. Computational type theory. Scholarpedia, 4(2):7618,
2009. URL [http://dx.doi.org/10.4249/scholarpedia.7618](http://dx.doi.org/10.4249/scholarpedia.7618.).

<a name="STER15">[6]</a>
Jonathan Sterling. Type theory and its meaning explanations. Unpublished
note, 2015. URL [https://arxiv.org/abs/1512.01837](https://arxiv.org/abs/1512.01837).

<a name="CMCP">[7]</a>
Per Martin-Löf. Constructive mathematics and computer programming.
In Logic, methodology and philosophy of science, VI (Hannover, 1979),
volume 104 of Stud. Logic Found. Math., pages 153–175. North-
Holland, Amsterdam, 1982. URL [https://doi.org/10.1016/S0049-237X(09)70189-2](https://doi.org/10.1016/S0049-237X(09)70189-2).