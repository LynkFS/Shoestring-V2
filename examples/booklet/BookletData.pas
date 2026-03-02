unit BookletData;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Booklet Data
//
//  Chapter content for the Shoestring booklet. Each chapter has a title
//  and an array of sections. Each section has a heading and body paragraphs.
//
//  Body text supports simple markers:
//    [code]...[/code]  — rendered as a code block
//    [quote]...[/quote] — rendered as a pull quote
//    Lines without markers — rendered as body text paragraphs
//
// ═══════════════════════════════════════════════════════════════════════════

interface

type
  TSection = record
    Heading: String;
    Body:    String;
  end;

  TChapter = record
    Title:    String;
    Sections: array of TSection;
  end;

function GetChapters: array of TChapter;

implementation

function GetChapters: array of TChapter;
begin
  Result := [

    // ── Chapter 1: Origins ───────────────────────────────────────────
    TChapter(Title: 'Origins', Sections: [

      TSection(Heading: 'The Itch', Body:
        'About five years ago, I started building a web framework. Not because the world needed another one, but because the ones I had were doing too much.' + #10 +
        'I was working with Smart Mobile Studio, a compiler that translates Object Pascal to JavaScript. SMS is a capable system with a rich component library, a visual designer, and a runtime that abstracts the browser into something resembling a traditional desktop application. Its successor, QTX (Quartex Pascal), carries that tradition forward with modern tooling and an active development community.' + #10 +
        'But I kept noticing something. The runtime library was reimplementing things the browser already knew how to do. Layout algorithms that recalculated pixel positions when the window resized, even though CSS flexbox handles that natively. Theme engines that generated inline styles, even though CSS custom properties let you change a single variable and watch every component update instantly.' + #10 +
        'Each of these features was well-engineered. Each solved a real problem. And each was unnecessary.' + #10 +
        'Shoestring has a different goal: to provide the thinnest possible typed layer over the browser itself.' + #10 +
        '[quote]Nothing during the development gave me more satisfaction than deleting chunks of code which were not absolutely necessary.[/quote]'),

      TSection(Heading: 'The Principle', Body:
        'The guiding rule is simple: if the browser does it, don''t.' + #10 +
        'When a traditional framework creates a button component, it might include properties for background colour, hover colour, border radius, font size, and a dozen other visual attributes. Each property has a getter, a setter, a backing field, and logic to apply it. A button can reach 200 lines before it does anything useful.' + #10 +
        'In Shoestring, a button is this:' + #10 +
        '[code]constructor TButton.Create(Parent: TElement);' + #10 +
        'begin' + #10 +
        '  inherited Create(''button'', Parent);' + #10 +
        '  AddClass(''btn'');' + #10 +
        'end;[/code]' + #10 +
        'Five lines. The visual appearance, hover state, focus ring, and transitions are all in a CSS class. CSS is purpose-built for visual presentation. Reimplementing it in Pascal means writing code that is worse than CSS at being CSS.'),

      TSection(Heading: 'Why Not a Competitor to QTX', Body:
        'Both frameworks compile Object Pascal to JavaScript. Both create DOM elements. The difference is in what they provide between Pascal and the browser.' + #10 +
        'QTX provides a complete abstraction layer: visual designer, property cache, state machine, theme engine, hundreds of runtime units. A QTX application interacts with the QTX runtime.' + #10 +
        'Shoestring provides typed access to the browser. No designer dependency, no property cache, no state machine. Pascal methods map one-to-one to CSS properties and DOM methods.' + #10 +
        'A QTX developer learns QTX. A Shoestring developer learns CSS and the DOM. Neither approach is superior. They serve different priorities.'),

      TSection(Heading: 'The Core', Body:
        'The entire framework compiles from five units. Everything descends from TElement, which wraps an HTML element.' + #10 +
        'Types.pas — external class bindings for browser APIs. At runtime, they cost nothing.' + #10 +
        'JElement.pas — TElement, the ancestor of everything. About 300 lines.' + #10 +
        'JForm.pas — TW3Form. About 50 lines.' + #10 +
        'JApplication.pas — form navigation with state preservation. About 60 lines.' + #10 +
        'Globals.pas — externals, stylesheet, theme variables, application init. About 120 lines.' + #10 +
        'Five units. Roughly 560 lines of Pascal. That is the entire framework.'),

      TSection(Heading: 'The Minimal Application', Body:
        '[code]program app;' + #10 +
        '' + #10 +
        'uses' + #10 +
        '  Globals, JForm, JPanel;' + #10 +
        '' + #10 +
        'type' + #10 +
        '  TForm1 = class(TW3Form)' + #10 +
        '  protected' + #10 +
        '    procedure InitializeObject; override;' + #10 +
        '  end;' + #10 +
        '' + #10 +
        'procedure TForm1.InitializeObject;' + #10 +
        'begin' + #10 +
        '  inherited;' + #10 +
        '  var Panel := JW3Panel.Create(Self);' + #10 +
        '  Panel.SetText(''Hello from Shoestring'');' + #10 +
        'end;' + #10 +
        '' + #10 +
        'begin' + #10 +
        '  Application.CreateForm(''Main'', TForm1);' + #10 +
        '  Application.GoToForm(''Main'');' + #10 +
        'end.[/code]' + #10 +
        'Compile with QTX. Drop the JavaScript into an index.html. One Pascal file, one HTML file, one compiled JavaScript file. No build system, no package manager, no bundler.')
    ]),

    // ── Chapter 2: Async ─────────────────────────────────────────────
    TChapter(Title: 'The Async Nature of the Web', Sections: [

      TSection(Heading: 'The Problem', Body:
        'In a desktop application, when you create a button and set its width to 200 pixels, it is 200 pixels wide immediately. In a browser, this is not true.' + #10 +
        'When you call document.createElement, the browser creates an element in memory. When you call appendChild, it enters the DOM tree. But the browser has not yet calculated its size. Those calculations happen asynchronously. Read offsetWidth immediately and you may get zero.' + #10 +
        'Every web framework must answer: when is a widget ready?'),

      TSection(Heading: 'Four Approaches', Body:
        'Promise + WhenReady (QTX): State machine with property cache. Complete but heavyweight — doubles component code.' + #10 +
        'MutationObserver: Watches parent''s childList. Must observe before appendChild or the callback never fires. Silent failure. N-squared scaling.' + #10 +
        'Promise.resolve() microtask: Simpler, same timing. But layout isn''t computed — offsetWidth may return zero.' + #10 +
        'requestAnimationFrame: Fires before the next repaint. Browser computes layout first. offsetWidth returns the real value.'),

      TSection(Heading: 'The Choice', Body:
        'Shoestring uses requestAnimationFrame. One line in the constructor:' + #10 +
        '[code]window.requestAnimationFrame(ElementReady);[/code]' + #10 +
        'No observer setup. No cleanup in the destructor. No ordering dependency. No N-squared scaling. The callback fires once, after layout is computed.' + #10 +
        'The tradeoff is up to ~16ms delay. For widget construction this is imperceptible.')
    ]),

    // ── Chapter 3: Positioning ───────────────────────────────────────
    TChapter(Title: 'Positioning', Sections: [

      TSection(Heading: 'Flex by Default', Body:
        'Every TElement is created with display:flex and flex-direction:column. This is the single most important design decision in the framework.' + #10 +
        'Children stack vertically. No positioning code needed. No Left, no Top, no SetBounds.' + #10 +
        '[code]var Header  := JW3Panel.Create(Self);' + #10 +
        'Header.Height := 48;' + #10 +
        '' + #10 +
        'var Content := JW3Panel.Create(Self);' + #10 +
        'Content.SetGrow(1);' + #10 +
        '' + #10 +
        'var Footer  := JW3Panel.Create(Self);' + #10 +
        'Footer.Height := 24;[/code]' + #10 +
        'Header-content-footer with zero positioning logic. Resize the browser and the content adjusts automatically.'),

      TSection(Heading: 'Why Not Left/Top/SetBounds?', Body:
        'The original had these on every element. They set CSS left and top via inline styles. In a flex container, left and top are ignored unless the element has position:absolute. Since every element defaulted to flex, these properties did nothing.' + #10 +
        'The redesign removes them. If a component needs absolute positioning, it sets position:absolute via SetStyle.'),

      TSection(Heading: 'Horizontal and Grid', Body:
        'For horizontal layout: SetStyle(''flex-direction'', ''row''). For two-dimensional layout: SetStyle(''display'', ''grid''). The framework provides SetStyle for both. It does not provide layout manager classes. The browser has layout engines.')
    ]),

    // ── Chapter 4: Styling and Theming ───────────────────────────────
    TChapter(Title: 'Styling and Theming', Sections: [

      TSection(Heading: 'Three Ways to Style', Body:
        'SetStyle writes to element.style (inline). Highest specificity. Use for runtime-dynamic values.' + #10 +
        'SetRule and SetRulePseudo write to the framework stylesheet. Use for pseudo-class states like :hover and :focus.' + #10 +
        'AddClass assigns a CSS class defined via AddStyleBlock. Use for static appearance shared across instances. This is the primary mechanism.'),

      TSection(Heading: 'CSS Variables as Design Tokens', Body:
        'Colours: --primary-color, --text-color, --bg-color, --surface-color. Semantic: --color-success, --color-danger.' + #10 +
        'Spacing: --space-1 (4px) through --space-16 (64px). Consistent rhythm.' + #10 +
        'Border radius: --radius-sm through --radius-full.' + #10 +
        'Elevation: --shadow-sm through --shadow-lg. Cards at sm, dropdowns at md, modals at lg.' + #10 +
        'Animation: --anim-duration. Change once, every transition adjusts.'),

      TSection(Heading: 'Dark Mode and Interaction States', Body:
        'Dark mode is a second set of variable values on :root.dark. Toggle one class, every component updates instantly. No event bus, no theme manager.' + #10 +
        'A shared .interactive class provides hover, focus, active, and disabled states. Any clickable component adds it and gets all four.'),

      TSection(Heading: 'Style Units', Body:
        'Styles are organised into Pascal units. Each exports string constants for class names (compile-time safety), registers CSS via AddStyleBlock, and auto-initialises. Import the unit, get the styles.')
    ]),

    // ── Chapter 5: Layout ────────────────────────────────────────────
    TChapter(Title: 'Layout', Sections: [

      TSection(Heading: 'The Layout Hierarchy', Body:
        'Media queries define page state: mobile versus desktop.' + #10 +
        'CSS Grid defines slots where components live.' + #10 +
        'Container queries define how a component looks inside its slot.' + #10 +
        'Flexbox handles alignment inside a component.' + #10 +
        'This is a decision guide, not a mandatory stack. Most elements use one or two of these.'),

      TSection(Heading: 'Layout Units', Body:
        'Six pre-built patterns as CSS class collections:' + #10 +
        'Dashboard — sidebar, header, auto-filling card grid.' + #10 +
        'Document — fixed header, centered content column, optional sidebar.' + #10 +
        'Split — two equal or weighted panels.' + #10 +
        'Holy Grail — header, footer, three columns.' + #10 +
        'Stacked — header, vertical sections, footer.' + #10 +
        'Kanban — header plus horizontal scrolling columns.'),

      TSection(Heading: 'Responsive Without Resize Events', Body:
        'Window resize listeners are removed from TElement. Only TW3Form listens for resize. Responsiveness is handled by CSS: media queries shift grid structure, flex containers wrap, container queries adapt components. No JavaScript needed.')
    ]),

    // ── Chapter 6: Typography ────────────────────────────────────────
    TChapter(Title: 'Typography', Sections: [

      TSection(Heading: 'Fluid Scaling', Body:
        'The base font size scales with the viewport using CSS clamp():' + #10 +
        '[code]:root { font-size: clamp(15px, 1vw + 12px, 18px); }[/code]' + #10 +
        'On a 375px phone: ~15.75px. On a 1440px desktop: ~17px. No media queries. One declaration and every rem value scales proportionally.'),

      TSection(Heading: 'The Type Scale and Prose', Body:
        'CSS variables from --font-size-xs (0.75rem) through --font-size-4xl (2.25rem). Utility classes apply them.' + #10 +
        '[code]Title.AddClass(''text-3xl'');' + #10 +
        'Title.AddClass(''font-bold'');' + #10 +
        'Body.AddClass(''text-prose'');[/code]' + #10 +
        'The prose class caps line length at 65 characters, sets relaxed line height, enables word wrapping and hyphenation. It protects readability regardless of container width.')
    ]),

    // ── Chapter 7: Forms and Validation ──────────────────────────────
    TChapter(Title: 'Forms and Validation', Sections: [

      TSection(Heading: 'The Field Base', Body:
        'Every form element needs a label, a value, a change event, and validation state. A shared CSS class defines the common visual identity:' + #10 +
        '[code].field {' + #10 +
        '  height: var(--field-height, 40px);' + #10 +
        '  padding: 0 var(--space-3);' + #10 +
        '  border: 1px solid var(--border-color);' + #10 +
        '  border-radius: var(--radius-md);' + #10 +
        '}' + #10 +
        '.field:focus { border-color: var(--primary-color); }' + #10 +
        '.field.invalid { border-color: var(--color-danger); }[/code]' + #10 +
        'Every form component adds AddClass(''field''). Change --field-height on :root and every field adjusts.'),

      TSection(Heading: 'Values, Events, and Validation', Body:
        'Form components expose value as a property that reads/writes the DOM element directly. No backing field. The browser is the single source of truth.' + #10 +
        'Validation is pure functions: IsRequired, IsEmail, MinLength. They know nothing about components:' + #10 +
        '[code]if not IsRequired(FEmail.Value) then' + #10 +
        '  FEmail.AddClass(''invalid'')' + #10 +
        'else' + #10 +
        '  FEmail.RemoveClass(''invalid'');[/code]' + #10 +
        'The class triggers styling. The function provides logic. The component provides the value.')
    ]),

    // ── Chapter 8: Building Components ───────────────────────────────
    TChapter(Title: 'Building Components', Sections: [

      TSection(Heading: 'The Pattern', Body:
        'Every component follows a three-part pattern:' + #10 +
        'A style unit registers CSS classes via AddStyleBlock. All visual definitions live here.' + #10 +
        'A Pascal class inherits from TElement. The constructor creates the HTML element, adds the CSS class, wires events.' + #10 +
        'String constants for class names give compile-time safety. A typo in csTabsBtn fails at compile time. A typo in ''tabs-btn'' fails silently at runtime.' + #10 +
        'The discipline: if the constructor exceeds ten lines, something that should be in CSS is probably in Pascal.'),

      TSection(Heading: 'What Components Do Not Do', Body:
        'Components do not manage their own themes — they reference CSS variables.' + #10 +
        'Components do not handle their own responsive behaviour — they use flexbox defaults or layout classes.' + #10 +
        'Components do not validate their own input — they expose values and fire events.' + #10 +
        'Each thing is done by the tool best suited to do it. CSS for appearance. The browser for layout. Pascal for structure and behaviour. Pure functions for validation.')
    ]),

    // ── Chapter 9: The Designer ──────────────────────────────────────
    TChapter(Title: 'The Designer', Sections: [

      TSection(Heading: 'Scaffold Generator, Not Runtime Dependency', Body:
        'In QTX, the designer produces QFM files that the runtime loads. The application depends on the designer''s output format.' + #10 +
        'In Shoestring, the designer produces Pascal source code. The output is a .pas file that compiles like any other unit. The designer''s internal state file is consumed only by the designer. The application never sees it.' + #10 +
        '[code]Designer (.design) -> .pas file -> Compiler -> Browser[/code]' + #10 +
        'No registration system, no serialisation protocol, no runtime loader. Delete the designer and the application still compiles.'),

      TSection(Heading: 'Round-Tripping and Export', Body:
        'Generated code uses guarded regions. The designer reads and writes within markers. Developer code outside is preserved.' + #10 +
        'Two export modes: HTML mode exports a complete page for web designers. Pascal mode exports a framework-compatible unit for developers. Both use the same AddClass, SetStyle, and constructors a developer would write by hand.')
    ]),

    // ── Chapter 10: Non-Visual Components ────────────────────────────
    TChapter(Title: 'Non-Visual Components', Sections: [

      TSection(Heading: 'Not Everything Is a DOM Element', Body:
        'A database connection does not need a div. Inheriting from TElement would create hidden DOM elements for every service and model instance.' + #10 +
        'Non-visual components are plain Pascal classes. They inherit from TObject. They do not touch the DOM.'),

      TSection(Heading: 'Four Categories', Body:
        'Services — long-lived, often global. Database connections, authentication managers.' + #10 +
        'Async operations — short-lived. HTTP requests. Often just a procedure with callbacks.' + #10 +
        'Models — data containers. Plain classes with fields and validation.' + #10 +
        'Adapters — bridges between visual and non-visual. A list adapter connects data to a list component.'),

      TSection(Heading: 'The HTTP Helper', Body:
        '[code]FetchJSON(''https://api.example.com/data'',' + #10 +
        '  procedure(Data: variant)' + #10 +
        '  begin' + #10 +
        '    // handle response' + #10 +
        '  end,' + #10 +
        '  procedure(Status: Integer; Msg: String)' + #10 +
        '  begin' + #10 +
        '    // handle error' + #10 +
        '  end' + #10 +
        ');[/code]' + #10 +
        'Wraps XMLHttpRequest, parses JSON, routes to callbacks. A standalone procedure, not a component.')
    ]),

    // ── Chapter 11: Node.js ──────────────────────────────────────────
    TChapter(Title: 'Node.js', Sections: [

      TSection(Heading: 'The Compiler Output Is JavaScript', Body:
        'DWScript compiles Object Pascal to JavaScript. That JavaScript currently targets the browser. Node.js has none of the browser APIs. But the compiled output is still JavaScript.' + #10 +
        'Not all Shoestring code depends on the browser. Data models, business logic, validation functions, and JSON serialisation are pure computation. Separate the browser-dependent code and the rest runs anywhere JavaScript runs.'),

      TSection(Heading: 'Separate Entry Points, Shared Logic', Body:
        '[code]/shared/          <- compiles to both targets' + #10 +
        '  Models.pas' + #10 +
        '  Validators.pas' + #10 +
        '' + #10 +
        '/browser/         <- browser entry point' + #10 +
        '  app_entrypoint.pas' + #10 +
        '  Globals.pas' + #10 +
        '' + #10 +
        '/node/            <- node entry point' + #10 +
        '  NodeApp.pas[/code]' + #10 +
        'Shared units never import browser-specific units. Both entry points import from shared. The discipline is simple: shared units never import browser units.'),

      TSection(Heading: 'What This Enables', Body:
        'Shared models mean the browser and server validate data with the same code. Change a validation rule once, both sides update.' + #10 +
        'Shared business logic means calculations are written once and run on the client for responsiveness and on the server for authoritative processing.' + #10 +
        'This is the practical consequence of compiling Pascal to JavaScript and being disciplined about which units import the DOM.')
    ])
  ];
end;

end.
