# The Pearl documentation

Pearl implements a variant of computational type theory like NuPRL [[1](#NuPRL)] and its descendents [[2](#MetaPRL), [3](#JonPRL), [4](#RedPRL)]. More precisely, the system serves as a "window on the truth" with respect to an intended informal realizability semantics which is defined independently of any formal theory. Inspired by Martin-Löf's early work [[5](#CMCP)], computational type theory views programs as realizers and not as formal proofs in a fixed and necessarily incomplete formal theory. See [[6](#CON09), [7](#STE15)] for accessible introductions.

We began the present implementation [here](https://github.com/bbentzen/cube) in 2019 using cubical features. After a long break due to research on the philosophical roots of computational type theory, the project was resumed in the summer of 2026 due to a confluence of reasons. The most important motivation is the completion of the monograph "Philosophical Type Theory" [[8](#BEN27)], which contains the most systematic exposition and defense of computational type theory to date, building on some key insights of Brouwer and Bishop on anti-formalism and human cognition. Pearl is an implementation of this dialect of computational type theory. Moreover, as Christoph Kreitz explains [here](https://proofassistants.stackexchange.com/q/2346/1048), the NuPRL group has disbanded and the original system is no longer easily accessible. RedPRL remains an excellent alternative, but we believe that cubical features may present a distraction from the premathematical essence of the computational view of type theory. Indeed, Pearl owes its very existence to the realization that the original implementation mentioned above, which was based on a cubical alternative to extensional type theory, could be decubicalized in a practical way.

Although inspired by NuPRL, Pearl deviates from it in two important ways. 

1. Pearl is intended to be consistent with classical reasoning in Bishop-style, while NuPRL ultimatitely favored the formalization of intuitionistic mathematics, 
including continuity principle, free choice sequences. and elements of Brouwer's creating subject arguments [[10](#BCC18), [11](#CON20)]. 

2. The main distinctive feature of Pearl is that it operates without a top-level layer of proof refinment logic as NuPRL, where users decompose proof goals into subgoals by means of refinement rules to extract realizers. Instead, Pearl is designed to get around the difficulties involving undecidable extensional equality without going too far beyond a proof term language in a style reminiscent of Andromeda [[9](#Andromeda)]. But while Andromeda is based on an explicitly typed language of algebraic effects and handlers intended to accommodate different user-definable rules for equality in general, Pearl is specifically based on a untyped programming language for computational type theory extended with only two opaque operations for reflection and explosion. 

As a case in point, note that this allows Pearl to prove function extensionality directly, in contrast to its usual status as a primitive rule in systems like NuPRL or Andromeda:

<p align="center">
  <img src="https://github.com/bbentzen/pearl/blob/main/doc/assets/funext.png?raw=true" />
</p>

Below you will find a short reference manual on the basics of Pearl. 

## The type theory of Pearl

For a more comprehensive account of the computatonal type theory implemented in Pearl we refer users to [[6](#BEN27), ch. 2]. Formally speaking, Pearl runs on a version of extensional type theory [[5](#CMCP)], a dependently typed theory with equality reflection. To keep the kernel as small as possible, the type theory of Pearl supports user-defined inductive type families and only runs on built-in type formers for dependent functions, the equality type, the empty type, and a cumulative hierarchy of universes à la Russell. Pearl's raw language is based on a Curry-style version of the untyped lambda-calculus extended with constants for type formers and their constructors and eliminators (when they exist).

- **Inductive type families** are defined by prescribing how to construct realizers for the type using the `inductive` environment, with their equality conditions and and eliminators derived automatically by the system. The language of Pearl is open-ended in the spirit of [[6](#BEN27), §9]. Every successful inductive definition of a type family introduces new constants for the type former, constructors, and eliminators. Note that eliminators are automatically generated under the name `foorec` for a type `foo`. 

- **Dependent function types** embody implications, functions, universal quantification, and indexed products with the given as `∏(x : M), N`,
where all free occurrences of `x` in `N` are bound. The constructor is given by
lambda abstraction `λ x.M`, and eliminator by application `M N`.
As usual, all free occurrences of `x` in `M` are bound in `λ x.M`. Since bound variables are represented using de Bruijin indices internally, we never
distinguish between the choice of bound variables in an expression. To be exact, the syntax of Pearl is based on locally nameless representation.

- **Equality type** express equality statements as `M = K N` or `eq K M N` and its constructor is given by the reflexivity constant `rfl`. As explained in [[7](#STE15), [8](#BEN27)], there is no need for a constant witnessing its elimination rule from the computational view of type theory: the semantics justifies a more general rule of inference on the level of judgments. This is the so-called reflection rule, which states that when the equality type is inhabited the two expressions are judgmentally equal at their type. When the user types `reflect M N` when proving a theorem and `M` realizes an equality type, the elaborator rewrites `N` and the current goal so that the terms are syntactically indistinguishable for unification purposes. This is achieved internally using explicit substitutions to keep track of reflected terms.

- **Empty type** expresses absurdity and empty collections as `void`. This type has no constructors and no eliminators. Again, there is no need for a constant witnessing ex falso. Computationally, explosion is well-justified on the level of judgments. Thus, when the user types `explode M N`  when proving a theorem and `M` realizes the empty type, the elaborator aborts the proof leaving `N` left as its realizer.

- **Universe types** are inhabited by types. Given the propositions-as-types, correspondence, there is no distinction between sets and propositions. Universe types are written as `type ℓ`, where `ℓ` is the level it lives in. There is a cumulative hierarchy of them, with type formers `type 0`, `type 1`, ... There are
no constructors and eliminators, as a consequence of Pearl's preferred
formulation of universes à la Russell.

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
To avoid redundency, Pearl does not allow for empty inductive type declarations given that the empty type is already taken as primitive.

### Proof environment

The proof environment is the main command where definitions are stated and theorems and lemmas are proven. Syntactically speaking, there is no difference between defintitions and theorems and lemmas. Users can use `def`, `definition`, `thm`, `theorem`, `lem`, and `lemma` interchangeably.

```
  def [name-of-theorem] [context] :
   [type] := [term]
```

Contexts are lists of variable declarations. Explicit variables are enclosed with `(` and `)` and must be passed as parameters when the definition or theorem is reused later. Implicit variables are enclosed with curly braces `{` and `}` and can be inferred by the elaborator. Multiple variables of the same type can be declared at the same time.


Primitive types | Notation | Constructors | Eliminators
------------ | ------------- | ------------- | -------------
Dependent function type	| Π (x : M), N | λ x , M | M N
Equality type | eq K M N | refl M | 
Empty type | void | | 
Universe type | type n | 

In addition, the user can also have `_` and `?` as placeholders in any expression. The former is used to synthesize an implicit assumption or fail after a number of steps, evaluating and displaying the type of the current goal. The latter is used to display the type of current goal directly without evaluation.

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

<a name="JonPRL">[3]</a>
Jonathan Sterling. JonPRL. 
[https://github.com/jonsterling/JonPRL](https://github.com/jonsterling/JonPRL).

<a name="RedPRL">[4]</a>
Carlo Angiuli, Evan Cavallo, Kuen-Bang Hou (Favonia), Robert Harper, and Jonathan Sterling. The RedPRL Proof Assistant (Invited Paper). In Proceedings of the 13th International Workshop
on Logical Frameworks and Meta-Languages: Theory and Practice, LFMTP@FSCD 2018,
Oxford, UK, 7th July 2018., pages 1–10, 2018. URL: 10.4204/EPTCS.274.1. URL [http://dx.doi.org/10.4204/EPTCS.274.1](http://dx.doi.org/10.4204/EPTCS.274.1).

<a name="CMCP">[5]</a>
Per Martin-Löf. Constructive mathematics and computer programming.
In Logic, methodology and philosophy of science, VI (Hannover, 1979),
volume 104 of Stud. Logic Found. Math., pages 153–175. North-
Holland, Amsterdam, 1982. URL [https://doi.org/10.1016/S0049-237X(09)70189-2](https://doi.org/10.1016/S0049-237X(09)70189-2).

<a name="CON09">[6]</a>
Robert L. Constable. Computational type theory. Scholarpedia, 4(2):7618,
2009. URL [http://dx.doi.org/10.4249/scholarpedia.7618](http://dx.doi.org/10.4249/scholarpedia.7618.).

<a name="STER15">[7]</a>
Jonathan Sterling. Type theory and its meaning explanations. Unpublished
note, 2015. URL [https://arxiv.org/abs/1512.01837](https://arxiv.org/abs/1512.01837).

<a name="BEN27">[8]</a>
Bruno Bentzen. Philosophical type theory. 
Logic, Epistemology, and the Unity of Science, volume 68. Springer, Cham. 202x.
URL [https://link.springer.com/book/9783032419392](https://link.springer.com/book/9783032419392).

<a name="Andromeda">[9]</a>
Andrej Bauer, Gaëtan Gilbert, Philipp Haselwarter, Matija Pretnar, and Christopher A. Stone. Design and implementation of the Andromeda proof assistant. TYPES, 2016. URL [http://www.types2016.uns.ac.rs/images/abstracts/bauer2.pdf](http://www.types2016.uns.ac.rs/images/abstracts/bauer2.pdf).

<a name="BCC18">[10]</a>
Mark Bickford, Liron Cohen, Robert L. Constable, and Vincent Rahli. Computability beyond Church-Turing via choice sequences. In Proceedings of the 33rd Annual
ACM/IEEE Symposium on Logic in Computer Science, LICS ’18, pages 245–254, New
York, NY, USA, 2018. ACM. URL [https://dl.acm.org/doi/10.1145/3209108.3209200](https://dl.acm.org/doi/10.1145/3209108.3209200)

<a name="CON20">[11]</a>
Robert Constable. Computational Complexity and Brouwer's Continuum. Unpublished note, 2020.
URL [https://nuprl-web.cs.cornell.edu/documents/Constable/The-Continuum.pdf](https://nuprl-web.cs.cornell.edu/documents/Constable/The-Continuum.pdf).
