<p align="center">
  <img src="https://github.com/bbentzen/pearl/blob/master/doc/assets/pearl-logo.png?raw=true" width="600"/>
</p>

<p align="center">
  <a href="https://github.com/bbentzen/pearl/stargazers" target="_blank"><img src="https://img.shields.io/github/stars/bbentzen/pearl?style=social" alt="GitHub stars"></a>
  <a href="https://github.com/bbentzen/pearl/blob/main/LICENSE" target="_blank"><img src="https://img.shields.io/github/license/bbentzen/pearl" alt="License"></a>
  <a href="https://github.com/bbentzen/pearl/releases" target="_blank"><img src="https://img.shields.io/github/v/release/bbentzen/pearl?include_prereleases" alt="Release"></a>
  <a href="https://github.com/ocaml/ocaml" target="_blank"><img src="https://img.shields.io/badge/Ocaml-4.14.2-blue" alt="OCaml"></a>
</p>

Pearl is an experimental interactive theorem prover for the formalization of mathematics from the computational view of type theory most recently advocated by Bentzen [[1](#BEN27)] following in the footsteps of Constable, Bickford, Allen, Harper, Sterling, Angiuli, and others. Pearl implements a version of extensional type theory with user-defined inductive type families inspired by NuPRL and its descendents [[2](#NuPRL), [3](#MetaPRL), [4](#RedPRL)], but without a proof refinement logic. Instead, Pearl focuses on proof terms in a style reminiscent of Andromeda [[5](#Andromeda)], except that instead of a explicitly typed language of algebraic effects and handlers, Pearl is based on a untyped programming language of realizers extended with only two opaque operations for reflection and explosion in theorem proving. Please see the documentation for more information on the underlying formal system.

## Installation

To install and use Pearl, you need OCaml version 4.14.2 or greater. We also recommend relying on the [opam](https://opam.ocaml.org/) package manager for installation. You will also need [menhir](https://opam.ocaml.org/packages/menhir/) for the LR(1) parser generator, and [dune](https://github.com/ocaml/dune) for building the project. Both can be installed using opam. It is best to ensure that your opam is up-to-date before installing the dependencies:

```
$ opam update && opam upgrade
$ opam install menhir dune base
```

Next, clone the repository and build the project using dune:

```
$ git clone https://github.com/bbentzen/pearl.git
$ cd pearl
$ dune build
```

This will create the executable `main.exe` which you can run on any `.pearl` file to typecheck its contents with Pearl. Since this compiled executable is typically be found under a subfolder such as `_build/default/bin`, you can run it as follows:

```
$ dune exec _build/default/bin/main.exe <filename>.pearl
```

However, we recommend using the pearl-vscode extension for verification support. More information can be found at [pearl-vscode/README.md](https://github.com/bbentzen/pearl/blob/master/pearl-vscode/README.md).

## Usage

Please see the reference manual on [doc/README.md](https://github.com/bbentzen/pearl/blob/master/doc/README.md).

## Support

This work was partly supported by the US Air Force Office of Scientific Research (AFOSR) grant FA9550-18-1-0120. Any opinions, findings and conclusions, or recommendations expressed in this material are those of the author and do not necessarily reflect the views of the AFOSR.

## References

<a name="BEN27">[1]</a>
Bruno Bentzen. Philosophical type theory. 
Logic, Epistemology, and the Unity of Science, volume 68. Springer, Cham. 202x.
URL [https://link.springer.com/book/9783032419392](https://link.springer.com/book/9783032419392).

<a name="NuPRL">[2]</a>
R. L. Constable, S. F. Allen, H. M. Bromley, W. R. Cleaveland, J. F.
Cremer, R. W. Harper, D. J. Howe, T. B. Knoblock, N. P. Mendler,
P. Panangaden, J. T. Sasaki, and S. F Smith. Implementing Mathematics
with The Nuprl Proof Development System. Prentice-Hall, 1986. URL [https://www.nuprl.org/book/](https://www.nuprl.org/book/).

<a name="MetaPRL">[3]</a>
Jason J. Hickey. The MetaPRL Logical Programming Environment. PhD thesis,
Cornell University, Ithaca, NY, January 2001. URL [https://dl.acm.org/doi/book/10.5555/932618](https://dl.acm.org/doi/book/10.5555/932618)

<a name="RedPRL">[4]</a>
Carlo Angiuli, Evan Cavallo, Kuen-Bang Hou (Favonia), Robert Harper, and Jonathan Sterling. The RedPRL Proof Assistant (Invited Paper). In Proceedings of the 13th International Workshop
on Logical Frameworks and Meta-Languages: Theory and Practice, LFMTP@FSCD 2018,
Oxford, UK, 7th July 2018., pages 1–10, 2018. URL: 10.4204/EPTCS.274.1. URL [http://dx.doi.org/10.4204/EPTCS.274.1](http://dx.doi.org/10.4204/EPTCS.274.1).

<a name="Andromeda">[5]</a>
Andrej Bauer, Gaëtan Gilbert, Philipp Haselwarter, Matija Pretnar, and Christopher A. Stone. Design and implementation of the Andromeda proof assistant. TYPES, 2016. URL [http://www.types2016.uns.ac.rs/images/abstracts/bauer2.pdf](http://www.types2016.uns.ac.rs/images/abstracts/bauer2.pdf).
