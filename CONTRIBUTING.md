We very much welcome contribution from human authors of all forms, including feedback sharing, bug reports, feature requests, improved documentation, and source code or library contributions. Before preparing a pull request (PR), which assumes that you have read the AI Use Policy found below, we ask that you please test your changes beforehand, running `dune build` to check that the Pearl source code compiles properly and then checking that nothing in the library `lib/all.prl` was broken.

## AI Use Guidelines

Pearl is written by human beings for human use and built on the convictions shared by Brouwer and Bishop that mathematics is a human activity. The practice of so-called "vibe coding" can undermine this vision and be highly detrimental to human understanding. As a first step, we encourage contributors to abide by the recommendations of the [AHM](https://www.ahmath.org/) and [AGMAI](https://agmai.org/) to protect human mathematics. Our rule of thumb is as follows: while low-impact use of AI for basic technical assistance and proofreading can be barely tolerated if they do not impact the human programming experience, contributors should explicitly acknowledge any further use and will only publish code that they are fully capable of producing on their own. 

## Desired features

Here are some items on our TODO list:

- Delay unification (in progress)
- Clearly separate elaboration, checking, and look for global identifier conflict when opening a binder only at elaboration stage
- Fix universe polymorphism bug when universe level occurs in proof
- Improve stack overflow error at synthetization attempts
- Do not automatically unfold terms tagged as theorem or as lemma
- Expand the library with more formalized math for testing strengths and limits
- Add structures
- Let-in local definitions
- Introduce Quotients types
- Opening of modules for referring to module.foo as foo
- Wildcard printing: user should not see inductive data as part of context when _ is entered in a proof (remove ind@ctx hack)
- Pretty print numbers in applied exprs (but not as levels) as sss...s0, e.g 2 as ss0
- Publish VS Code extension
- Proper readthedocs documentation