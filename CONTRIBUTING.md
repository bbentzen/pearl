We now welcome contribution from human authors of all forms, including feedback sharing, bug reports, feature requests, improved documentation, and source code or library contributions. Before preparing a pull request (PR), which assumes that you have read the AI Use Policy found below, we ask that you please test your changes beforehand, running `dune build` to check that the Pearl source code compiles properly and then checking that nothing in the library `lib/all.prl` was broken.

## AI Use Guidelines

We firmly believe that mathematics is built on the exercise of human judgment. This has been embraced as a core tenet of mathematical constructivism by Brouwer and Bishop from the very beginning long before mathematicians became aware of the serious threats presently posed by AI. We are fully committed to the preservation of human understanding without any relevant use of AI-generative tools. In fact, the spirit of our computational view of type theory is most beautifully expressed in Bishop's words:

> Mathematics that has computational meaning may require the exercise
of judgment before that meaning is discharged. Whether a given rule
generates a constructively deﬁned sequence of integers [...] require[s]
judgment. If the judgment is not unanimous, either the mathematics is
bad or the judgment of at least one of the judges is bad. This is the dif-
ference between man and the presently available computers: We exercise
judgment, and the computers do not. Because the computer is lacking in
judgment, the theorems of constructive mathematics do not in general
represent computer programs. They represent person programs, which in
some instances can be transformed into computer programs and in other
instances cannot. [Foundations of constructive analysis, pp. 354–355]

Pearl is written by human beings for human use and built on the convictions shared by Brouwer and Bishop that mathematics is a human activity. The practice of so-called "vibe coding" can undermine this vision and be highly detrimental to human understanding. As a first step, we encourage contributors to read the recommendations on the [Leiden declaration](https://leidendeclaration.ai/), the [AHM](https://www.ahmath.org/), and [AGMAI](https://agmai.org/) to protect human mathematics. Our rule of thumb is as follows: while low-impact use of AI for basic technical assistance and proofreading can be tolerated if they do not impact the human programming experience, contributors should explicitly acknowledge any further use and will only publish code that they are fully capable of producing on their own. 

## Desired features

Here are some items on our TODO list:

- Kernel typechecking after elaboration (almost complete)
- Delay unification (in progress)
- When a: A is declared in the context the typehood of A should be inferred a la PER semantics and PTT rather than checked
- Clearly separate elaboration, checking, and look for global identifier conflict when opening a binder only at elaboration stage
- Improve stack overflow error at synthetization attempts
- Expand the library with more formalized math for testing strengths and limits
- Pretty print user-named definitions 
- Pretty print numbers in applied exprs (but not as levels) as sss...s0, e.g 2 as ss0
- Publish VS Code extension
- Add structures
- Let-in local definitions
- Opening of modules for referring to module.foo as foo
- Better documentation (in progress)

## Disclaimer

This is an academic project maintained by a small group at Zhejiang University in part time. This project is driven by our philosophical credo that the justificatory value of theorem proving in a proof assistant is predicated on its own justifiation. The goal is not to compete with Agda, Lean, Rocq, Idris on practical grounds but to build a proof assistant that prioritizes its own philosophical justification over anything else.