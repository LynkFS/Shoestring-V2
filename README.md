# Shoestring-V2
Web and Node development framework

*A Minimalist Web Framework in Object Pascal*

About five years ago, I started building a web framework. Not because the world needed another one, but because I could. At least that's what I thought at the time.

I was working with Smart Mobile Studio, a compiler that translates Object Pascal to JavaScript. SMS is now defunct but was a capable system with a rich component library and, in its later incarnations, a visual designer. It worked. I built real applications with it, as did many other developers. Its successor, QTX (Quartex Pascal), carries that tradition forward with modern tooling and an active development community.

But part of my motivation was also to build something minimal — as lean as it gets. Both the browser and Node.js environments expose an enormous amount of well-designed, well-tested, functioning APIs and I wanted to use as much of that as possible.

So I started Shoestring. Not as a competitor to SMS or QTX, Shoestring had a different goal: to provide the thinnest possible typed layer over the browser itself. Every line of Pascal should map to something the browser does. If the browser already provides a capability, Shoestring exposes it. It does not reimplement it, wrap it, abstract it, or improve upon it.

Nothing during the development gave me more satisfaction than deleting chunks of code which were not absolutely necessary.

ShoeString in action : see [the kitchen sink application.](https://lynkfs.com/docs/ss-v2), and [this link](https://lynkfs.com/docs/ss-v2/booklet) for explanations, architectural choices and documentation.
