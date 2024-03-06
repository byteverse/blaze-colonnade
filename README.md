To run doctests:

First make sure `doctest` is on the `PATH` (i.e. `cabal install doctest`).

Then run:

```
cabal repl --build-depends=QuickCheck,profunctors --with-ghc=doctest --repl-options="-fno-warn-orphans -Wno-x-partial" blaze-colonnade
```
