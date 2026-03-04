# Shoestring-V2

Web and Node development framework

*A Minimalist Web Framework in Object Pascal*

## Design Goal

ShoeString-V1 began as a thin, typed layer over the browser — not a competitor to QTX or Smart Mobile Studio, which give Pascal developers a full component model with designers, property editors, and a runtime library that abstracts the browser entirely.

ShoeString had a different objective: expose browser APIs directly, without reimplementing, wrapping, or abstracting them. Every Pascal method maps one-to-one to a CSS property, DOM method, or browser API. If the browser provides it, ShoeString does not reimplement it.


## ShoeString-V2

Five years of use identified areas for improvement :

- Simpler async readiness model
- A layout system (six pre-built patterns)
- Improved styling: CSS variables, dark mode, three styling mechanisms
- Improved typography
- Rewritten visual and non-visual components
- Positioning flexibility
- Container queries for component-level responsiveness


ShoeString-V2 is the upgraded and enhanced version of the original framework.

To get a feel for it, see ShoeString-V2 in action : [a comprehensive kitchensink demo.](https://lynkfs.com/docs/ss-v2), and follow [this link](https://lynkfs.com/docs/ss-v2/booklet) for explanations, architectural choices and documentation.
