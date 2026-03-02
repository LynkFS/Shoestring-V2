# Shoestring-V2
Web and Node development framework
**ShoeString2**

*A Minimalist Web Framework in Object Pascal*

Nico

Fifth Edition — February 2026

**Chapters**

1. Origins

2. The Async Nature of the Web

3. Positioning

4. Styling and Theming

5. Layout

6. Typography

7. Forms and Validation

8. Building Components

9. Complex Components

10. The Designer

11. Non-Visual Components

12. Node.js

#  Chapter 1: Origins

## The Itch

About five years ago, I started building a web framework. Not because the world needed another one, but because I could. At least that's what I thought at the time.

I was working with Smart Mobile Studio, a compiler that translates Object Pascal to JavaScript. SMS is now defunct but was a capable system with a rich component library and, in its later incarnations, a visual designer. It worked. I built real applications with it, as did many other developers. Its successor, QTX (Quartex Pascal), carries that tradition forward with modern tooling and an active development community.

But part of my motivation was also to build something minimal — as lean as it gets. Both the browser and Node.js environments expose an enormous amount of well-designed, well-tested, functioning APIs and I wanted to use as much of that as possible.

So I started Shoestring. Not as a competitor to SMS or QTX. Those frameworks give (Delphi) developers a familiar, full-featured environment for building web applications — designers, component palettes, property editors, and runtime libraries that make the browser feel like Windows.

Shoestring had a different goal: to provide the thinnest possible typed layer over the browser itself. Every line of Pascal should map to something the browser does. If the browser already provides a capability, Shoestring exposes it. It does not reimplement it, wrap it, abstract it, or improve upon it.

Nothing during the development gave me more satisfaction than deleting chunks of code which were not absolutely necessary.

## The Principle

The guiding rule is simple: if the browser or node.js does it, don’t.

Shoestring provides typed access to the browser. There is no visual designer dependency, no property cache, no state machine, no theme engine. A Shoestring application interacts with the browser directly, through Pascal methods that map one-to-one to CSS properties, DOM methods, and browser APIs.

A Shoestring developer uses the DOM, HTML, CSS and Javascript, with Pascal as the language to write it in.

## The Core

The entire framework compiles from five core units plus one entry point :

**JElement.pas** defines TElement, the ancestor of everything. Everything in Shoestring descends from this class, the application object, forms, panels, buttons, toolbars and anything else. 
A single variant field — FHandle — holds the DOM element. Every DOM method works through variant dispatch. The class manages child tracking, lazy click binding, CSS class manipulation, inline styles, stylesheet rules, and pseudo-class rules. About 350 lines.

**JForm.pas** defines TW3Form. About 50 lines.

**JApplication.pas** manages form navigation. About 55 lines.

**Globals.pas** declares browser externals, creates the framework stylesheet for per-element rules, applies body defaults, generates element IDs, and provides a couple of helper functions. About 280 lines.

**Types.pas** declares external class bindings for browser api's. Only the ones which are used by the framework. About 100 lines. 

Five units. Roughly 850 lines. That is the entire framework.

## The Minimal Application

The most minimal Shoestring application: a form with a panel

```pascal
Unit Form1;
uses
Globals, JForm, JPanel;
type
TForm1 = class(TW3Form)
protected
procedure InitializeObject; override;
end;
procedure TForm1.InitializeObject;
begin
inherited;
var Panel := JW3Panel.Create(Self);
Panel.SetText('Hello from Shoestring');
end;
```

One Pascal file, one HTML file, one compiled JavaScript file. No build system, no package manager, no bundler.

## The Redesign

Five years of use reveals what could be done better, so I felt the need for a refresher, a redesign

ShoeString2 rethinks the framework around these goals:

- A simpler way to handle the async nature of the web

- Simplified code for the core components

- A layout system

- Improved styling including typography

- Rewritten and new visual and non-visual components

- Positioning methods

- Container queries for component-level responsiveness

#  Chapter 2: The Async Nature of the Web

## The Problem

When a framework calls document.createElement, the browser creates an element in memory. When it calls appendChild, the element is inserted into the DOM tree. But the browser has not yet calculated its position, its size, or its visual appearance. Those calculations happen later, asynchronously. If you read offsetWidth immediately after creation, you may get zero.

Every web framework must answer the question: when is a widget ready?

## Four Approaches

**1 MutationObserver** on the parent’s childList. This is the method used in the original Shoestring. It watches for child additions and fires on the DOM insertion event. It works, but the observer must be set up before appendChild, and it scales quadratically with siblings.

**2 Promise.resolve()** microtask. Schedules a microtask after the current code completes. Same timing as MutationObserver, simpler implementation. But layout is not guaranteed to be computed.

**3 Promise with WhenReady**. Every widget transitions through creating, ready, and destroying states. Properties set before ready are cached and flushed to the DOM when the widget reaches ready. Architecturally complete, but requires machinery: a state machine, a property cache, and a notification system. QTX has robustly implemented this.

**4 RequestAnimationFrame**. Schedules a callback before the browser’s next repaint. The browser computes styles and layout before calling it. offsetWidth returns the real value.

## The Choice

Shoestring2 uses requestAnimationFrame because of its reliability and simplicity. Just one line in the constructor:

```
window.requestAnimationFrame(ElementReady);
```

No observer setup. No cleanup in the destructor. No ordering dependency. No N² scaling. No silent failure modes. The callback fires once, after layout is computed.

The tradeoff is up to 16ms of delay. For widget construction this is imperceptible. The developer assigns OnReady only if they need to read computed dimensions. In all other cases the callback does nothing.

```pascal
Panel.OnReady := procedure(Sender: TObject)
begin
console.log(Panel.Width); // reliable
end;
```

#  Chapter 3: Positioning

## Being flexible

The original Shoestring used absolute positioning. SetBounds(left, top, width, height) placed every element with pixel precision. It worked well for simple layouts.

The drawback was composite elements. A listbox had to position every item below its predecessor, accounting for borders and padding. Changing layout from desktop to mobile meant writing completely different positioning arithmatic.

The browser has a built-in solution. Its CSS layout system is fast and handles all of this without user-compute. Really the easiest way to position elements on a page is to use display: flex and flex-direction: column. When you create child elements inside a parent, they stack vertically. No positioning code needed. No Left, no Top, no SetBounds. Children appear in order. The browser handles the layout.


```pascal
var Header := JW3Panel.Create(Self);
Header.Height := 48;
var Content := JW3Panel.Create(Self);
Content.SetGrow(1); // fills remaining space
var Footer := JW3Panel.Create(Self);
Footer.Height := 24;
```

This produces a header-content-footer layout with zero positioning logic. Resize the browser and the content adjusts automatically.

The original Shoestring had Left, Top, and SetBounds on every element. These set CSS left and top via inline styles. In this redesign this is now removed from TElement. 
This is not a mandatory change, developers can still use absolute positioning. If a component genuinely needs it — a modal overlay, a dropdown — just set position: absolute via SetStyle and then uses SetStyle for left and top.

## Horizontal and Grid

For horizontal layout, override the direction: SetStyle(‘flex-direction’, ‘row’). For two-dimensional layout, switch to grid: SetStyle(‘display’, ‘grid’). The framework provides SetStyle for both. It does not provide layout manager classes. The browser has layout engines. Shoestring gives you typed access to them.

#  Chapter 4: Styling and Theming

## Three Ways to Style

CSS has three styling mechanisms: inline styles, stylesheet rules, and classes. They overlap and have different specificity rules. Inline styles have the highest specificity but cannot express all CSS constructs.

I read somewhere this description : Think of CSS styling methods like the different ways you can give instructions to a tailor. You can yell specific directions while they're sewing (inline), hand them a master list of rules for the whole shop (stylesheet), or create a "template" that can be applied to any suit they make (classes).

The original Shoestring had two of the three: SetProperty for inline styles and SetCSS for stylesheet rules including pseudo-elements like :hover.

Shoestring2 adds the class methodology. TElement now has all three:

- **SetStyle** which writes to element.style (inline). Highest specificity. Use for runtime-dynamic values. It directly manipulates the properties of the html style attribute : style=”background-color: black;”

- **SetRule, SetRulePseudo and SetRuleMedia** write rules to the framework stylesheet, targeting elements by their unique ID. Use for pseudo-class states like :hover and :focus, which cannot be expressed inline and can be used for media queries.

- **AddClass** assigns a CSS class. The class is defined via AddStyleBlock, a standalone procedure in Globals that creates a \<style\> element and appends it to the document head. Use for static appearance shared across all instances. This is the primary styling mechanism and includes all possible CSS constructs: double colon pseudo elements (::before), compound selectors (:hover:not(:disabled)), combinators (.toolbar \> \*:last-child), @keyframes, @container queries, @font-face and more. Except for container queries these are rarely used, but they’re there if you need them.

## The Rules

There are no strict rules — use whatever method suits the situation. The components in this framework follow a convention though: Classes for appearance, SetStyle for state. If the style is the same for every instance, it uses a class. If it varies per instance or changes at runtime, it uses SetStyle.

**The full picture:**

AddStyleBlock with CSS classes handles component internals — hover states, focus rings, transitions, pseudo-elements, scrollbar styling, and shared rules across all instances. SetStyle handles per-instance overrides — runtime values, conditional visibility, dynamic sizing. SetRulePseudo covers per-element pseudo-classes that vary by instance. Layout units (more of that later, see chapter 6) add media queries and container queries via AddStyleBlock because these target multiple elements across breakpoints.

A developer using the framework typically only calls SetStyle, same as before. The CSS class code lives inside the component, written once by the component author.

## CSS Variables as Design Tokens

The framework defines CSS custom properties on :root. These are the shared vocabulary that every component references. All design tokens live in ThemeStyles.pas — the single source of truth for the visual system. The font-size scale lives separately in TypographyStyles.pas. Globals declares no variables.

**Colours:** --primary-color, --text-color, --bg-color, --surface-color, --border-color, --hover-color. Semantic extensions: --color-success, --color-warning, --color-danger, --color-info. Each semantic colour has a -bg variant for soft backgrounds.

**Spacing:** --space-1 (4px) through --space-16 (64px). Consistent rhythm across every component.

**Border radius:** --radius-sm through --radius-full. Shared shape language.

**Elevation:** --shadow-sm through --shadow-xl. Cards at sm. Dropdowns at md. Modals at lg.

**Animation:** --anim-duration. Change it once, every transition adjusts.

**Field tokens:** --field-height, --field-padding, --field-border, --field-radius, --field-bg, --field-focus-border, --field-focus-ring. Every form element references these for consistency.

## Dark Mode

A dark theme is a second set of variable values applied via a class on the root element:

```css
:root { --bg-color: \#f8fafc; --text-color: \#334155; }
:root.dark { --bg-color: \#0f172a; --text-color: \#e2e8f0; }
```

Toggle with one line of JavaScript. Every component updates instantly. No event bus. No theme manager. ThemeStyles.pas defines the complete dark palette including adjusted shadows and semantic colour variants.

## Interaction States

A shared .interactive class provides hover, focus-visible, active, and disabled states. Any clickable component adds AddClass('interactive') and gets all four, consistent with every other interactive element.

#  Chapter 5: Typography

## Fluid Scaling

The base font size scales with the viewport using CSS clamp():

```css
:root { font-size: clamp(15px, 1vw + 12px, 18px); }
```

On a 375px phone: ~15.75px. On a 1440px desktop: ~17px. Never below 15px, never above 18px. No media queries, no JavaScript. One declaration and every rem value scales proportionally. This is declared in TypographyStyles.pas, which is the single owner of the font-size scale.

## The Type Scale

CSS variables define sizes from --font-size-xs (0.75rem) through --font-size-4xl (2.25rem). Utility classes apply them. Heading sizes switch to tight line height automatically.

```
Title.AddClass('text-3xl');
Title.AddClass('font-bold');
Body.AddClass('text-prose');
```

## The Prose Class

text-prose caps line length at 65 characters, sets relaxed line height, enables word wrapping and hyphenation. It protects readability independent of container width.

## Monospace

text-mono applies a monospace font at 0.9em. The reduction keeps inline code visually consistent with surrounding proportional text.

#  Chapter 6: Layout

## Layout Units

You can use any browser layout feature directly. Absolute positioning for precise placement, flexbox for one-dimensional vertical or horizontal flow, grid for two-dimensional layouts.

Beyond that, Shoestring2 includes six pre-built layout patterns. They work on both desktop and mobile, and every element within them can host additional components.

1.  **Dashboard** — sidebar, header, auto-filling card grid. Collapses to single column on mobile via media query.


![Generator](images/Picture1.png "Dashboard layout")

2.  **Document** — fixed header, centered content column with max-width, optional sidebar.


![Generator](images/Picture2.png "Document layout")

3.  **Split** — two equal or weighted panels, horizontal or vertical.


![Generator](images/Picture3.png "Split layout")

4.  **Holy Grail** — header, footer, three columns.


![Generator](images/Picture4.png "Holy grail layout")

5.  **Stacked** — header, vertical sections, footer. The simplest full-page layout.


![Generator](images/Picture5.png "Stacked layout")

6.  **Kanban** — header plus horizontal scrolling columns for board-style layouts.


The first five are all variations of vertical/grid arrangements. Kanban is the one common application pattern that's fundamentally different — horizontal scrolling columns. Trello, Jira, GitHub Projects, Monday.com, Notion boards all use it. It exercises overflow-x: auto on the shell and overflow-y: auto on each column, which none of the other five layouts do.

Each is tuneable via CSS variables with sensible defaults. Override a variable on one element to customise that instance. Override on :root to customise all.

Example of form using the document layout :

```
unit FormArticle;

interface

uses JElement, JForm, JPanel, LayoutDocument;      //Document layout

type
  TFormArticle = class(TW3Form)
  private
    Shell:   JW3Panel;
    Header:  JW3Panel;
    Body:    JW3Panel;
    Content: JW3Panel;
    Aside:   JW3Panel;
  protected
    procedure InitializeObject; override;
  end;

implementation

uses Globals, JButton, JLabel, TypographyStyles;

procedure TFormArticle.InitializeObject;
begin
  inherited;

  // ── Structure ──────────────────────────────────────────────────────

  Shell := JW3Panel.Create(Self);
  Shell.AddClass(csDocShell);

  Header := JW3Panel.Create(Shell);
  Header.AddClass(csDocHeader);

  Body := JW3Panel.Create(Shell);
  Body.AddClass(csDocBody);

  Content := JW3Panel.Create(Body);
  Content.AddClass(csDocContent);
  Content.AddClass('prose');
  Content.SetStyle('gap', '16px');

  Aside := JW3Panel.Create(Body);
  Aside.AddClass(csDocAside);

  // ── Header ─────────────────────────────────────────────────────────

  var Logo := JW3Label.Create(Header);
  Logo.SetText('Paris Guide');
  Logo.SetStyle('font-weight', '700');
  Logo.SetStyle('font-size', '1.1rem');

  // ── Article ────────────────────────────────────────────────────────

  var Title := JW3Panel.Create(Content);
  Title.SetText('Paris');
  Title.AddClass('text-2xl');
  Title.AddClass('font-bold');

  var Subtitle := JW3Panel.Create(Content);
  Subtitle.SetText('The City of Light');
  Subtitle.SetStyle('color', 'var(--text-light, #64748b)');
  Subtitle.SetStyle('font-size', 'var(--font-size-md, 1rem)');

  var P1 := JW3Panel.Create(Content);
  P1.SetText(
    'Paris sits on the River Seine in northern France, a city of two million ' +
    'people at its core and twelve million across the greater metropolitan area. ' +
    'It has been the cultural, economic, and political heart of France for over ' +
    'a thousand years. The city is organised into twenty arrondissements that ' +
    'spiral outward from the centre like a snail shell.'
  );

  var H2 := JW3Panel.Create(Content);
  H2.SetText('Landmarks');
  H2.AddClass('text-xl');
  H2.AddClass('font-bold');
  H2.SetStyle('margin-top', '8px');

  var P3 := JW3Panel.Create(Content);
  P3.SetText(
    'The Eiffel Tower ..... etc etc'
  );


  // ── Sidebar ────────────────────────────────────────────────────────

  var NavTitle := JW3Label.Create(Aside);
  NavTitle.SetText('On this page');
  NavTitle.SetStyle('font-weight', '600');
  NavTitle.SetStyle('font-size', '0.8rem');
  NavTitle.SetStyle('color', 'var(--text-light)');
  NavTitle.SetStyle('text-transform', 'uppercase');
  NavTitle.SetStyle('letter-spacing', '0.05em');

  var Link1 := JW3Label.Create(Aside);
  Link1.SetText('Paris');
  Link1.SetStyle('color', 'var(--primary-color)');
  Link1.SetStyle('font-size', '0.875rem');
  Link1.SetStyle('cursor', 'pointer');
  Link1.OnClick := procedure(Sender: TObject)
  begin
    Title.Handle.scrollIntoView(true);
  end;

  var Link2 := JW3Label.Create(Aside);
  Link2.SetText('Landmarks');
  Link2.SetStyle('color', 'var(--text-color)');
  Link2.SetStyle('font-size', '0.875rem');
  ...

end;

end.
```

## Responsive Without Resize Events

The redesign removes window resize listeners from TElement entirely. Only TW3Form listens for resize. Responsiveness is handled by CSS: media queries shift grid structure, flex containers wrap, container queries adapt components. No JavaScript resize events needed. The browser handles it with hardware acceleration.

## Overflow and Mobile

Two components feature explicit overflow handling for narrow viewports. JDataGrid’s body wrapper uses overflow-x: auto so wide tables scroll horizontally instead of clipping content. JTreeView adds the same — deeply nested nodes scroll horizontally rather than overflowing off-screen. Every other component is inherently responsive: flex-wrap handles toolbars, overflow-x: auto with hidden scrollbar handles tab strips, max-width: calc(100vw − 32px) constrains modals.

## Container Queries

Media queries respond to the viewport. Container queries respond to the component’s own width. A product card in a narrow sidebar stacks vertically. The same card in a wide content area goes horizontal. The viewport did not change — the container did.

The pattern: the parent declares container-type: inline-size. The child uses CSS Grid with a default single-column layout. A @container rule switches to multi-column when the container is wide enough. One property change — grid-template-columns — restructures the entire card. No wrapper divs, no JavaScript.

Container queries only apply to descendants, never to the container itself. This is a CSS rule, not a framework limitation. If a component needs to restructure its own layout, it uses an inner wrapper or the parent provides the container context. In practice, a simple AddClass(‘card-container’) on any parent is enough.

This pattern is not appropriate for every component. Buttons, inputs, checkboxes, and labels do not need layout restructuring at any size. Container queries belong on components with internal structure that genuinely changes shape — cards, dashboard panels, product listings. Use them where grid restructuring adds value. Keep flex for everything that simply stacks or flows.

JProductCard is a good example of this.

#  Chapter 7: Forms and Validation

## What Form Elements Share

Every form element needs a label, a value, a change event, and validation state. If each component implements these independently, you may get subtle inconsistencies that users perceive as “unpolished.”

## The Field Base

A shared .field class in ThemeStyles defines height, padding, border, radius, font size, transition, focus ring, invalid state, and disabled state. Every form component adds AddClass('field'). Change --field-height on :root and every field adjusts. The .field-label, .field-group, and .field-error classes provide consistent form layout without any Pascal code.

## Values and Events

Form components expose their value through a property that reads from and writes to the DOM element directly. No backing field. No cache. The browser is the single source of truth.

## Validation

Validations are a set of functions in Validators.pas: IsRequired, IsEmail, IsNumeric, IsInteger, IsURL, MinLength, MaxLength, ExactLength, InRange, Matches. They return true or false. They have zero DOM dependency and compile to both browser and Node.js targets.

The developer calls them and applies the result:

```
if not IsRequired(FEmail.Value) then
FEmail.AddClass('invalid')
else
FEmail.RemoveClass('invalid');
```

The class triggers styling. The function provides logic. The component provides the value. Each piece does one thing.

#  Chapter 8: Building Components

## The Pattern

Every component follows a three-part pattern:

**A style unit** registers CSS classes via AddStyleBlock in its initialization section. A guard flag prevents double-registration. All visual definitions live here.

**A Pascal class** inherits from TElement. The constructor creates the HTML element, adds the CSS class, wires events. The class exposes a typed API for component-specific behaviour.

**String constants** for class names give compile-time safety. A typo in csTabsBtn fails at compile time. A typo in 'tabs-btn' fails silently at runtime.

The discipline: if the constructor exceeds ten lines, something that should be in CSS is probably in Pascal.

## Exceptions to the Ten-Line Rule

JCheckbox is a deliberate exception. It creates internal DOM elements because the \<label\> wrapping \<input\> + \<span\> is an atomic HTML pattern, not a composable parent-child structure. The browser’s native checkbox accessibility depends on this specific nesting. The constructor is longer because the HTML structure demands it, not because CSS work leaked into Pascal.

## Click Handling

OnClick uses lazy binding. The DOM event listener is attached only when OnClick is first assigned. A page with 200 panels but only 5 buttons gets 5 listeners, not 200. CBClick does not call stopPropagation — events bubble normally through the DOM tree. Components that need isolation, like a modal preventing backdrop clicks, call stopPropagation explicitly.

## Child Lifecycle

TElement tracks its children in an internal array. The constructor registers with the parent. The destructor iterates children backwards, freeing each one, then unregisters from the parent’s array, then removes itself from the DOM. The Clear method frees all children. No orphaned Pascal objects remain when a container is destroyed.

## What Components Do Not Do

Components do not manage their own themes. They reference CSS variables. Components do not validate their own input. They expose values and fire events. Responsive behaviour is handled at two levels: layout units use media queries for viewport-level restructuring, and components that need container-aware responsiveness use CSS Grid with container queries.

Each thing is done by the tool best suited to do it. CSS for appearance. The browser for layout. Pascal for structure and behaviour. Pure functions for validation.

## Class-less components

Every styling method in TElement works without CSS classes too. Here is the toolbar constructor using only SetStyle and SetRulePseudo:

```
{ JW3Toolbar }

constructor JW3Toolbar.Create(Parent: TElement);
begin
inherited Create('div', Parent);
SetStyle('flex-direction', 'row');
SetStyle('align-items', 'center');
SetStyle('flex-wrap', 'wrap');
SetStyle('gap', 'var(--tb-gap, 4px)');
SetStyle('padding', 'var(--tb-padding, 4px 8px)');
SetStyle('min-height', 'var(--tb-height, 40px)');
SetStyle('background', 'var(--tb-bg, var(--surface-color, \#ffffff))');
SetStyle('border-bottom', 'var(--tb-border, 1px solid var(--border-color, \#e2e8f0))');
SetStyle('user-select', 'none');
end;

{ TToolbarItem }

constructor TToolbarItem.Create(Parent: TElement);
begin
inherited Create('div', Parent);
SetStyle('display', 'inline-flex');
SetStyle('flex-direction', 'row');
SetStyle('align-items', 'center');
SetStyle('justify-content', 'center');
SetStyle('gap', '6px');
SetStyle('flex-shrink', '0');
SetStyle('padding', 'var(--tb-item-padding, 6px 12px)');
SetStyle('min-height', '32px');

etc..
```

No RegisterToolbarStyles, no AddStyleBlock, no CSS classes, no AddClass. CSS variables still work. Pseudo-classes work via SetRulePseudo.

The cost: 100 toolbar items emit 200 per-element hover/active rules instead of sharing 2 class rules. For a typical app with a handful of toolbars, irrelevant. For a datagrid rendering 10,000 cells, you'd want classes.

# Chapter 9: Complex Components

## Beyond Simple Wrappers

The components described so far — buttons, inputs, cards, badges — are thin wrappers over single HTML elements. Their constructors are short, their CSS is straightforward, and their behaviour is minimal. But enterprise applications need components that are genuinely complex: tree views for hierarchical data, data grids for tabular data etc. These require algorithms, not just CSS classes.

This chapter describes two components that push the framework’s philosophy into more demanding territory and shows that the principle — if the browser does it, don’t — still applies, even when the browser needs substantial help.

## Tree View

JTreeView renders hierarchical data with expand/collapse, keyboard navigation, lazy loading, and ARIA roles. The API is simple:

```pascal
Tree := JW3TreeView.Create(Panel);
var Root := Tree.AddNode(nil, 'Documents');
var Work := Tree.AddNode(Root, 'Work');
Tree.AddNode(Work, 'Report.docx');
```

Each node is a TTreeNode record that owns a Row (toggle + label), a ChildrenEl container, and an array of child nodes. Indentation is calculated via CSS: calc(depth \* var(--tree-indent, 20px) + 8px). The toggle is a Unicode triangle that rotates 90 degrees via CSS transform when expanded. Children are hidden by toggling a CSS class that sets display: none.

### Lazy Loading

Set Node.IsLazy := true and assign Node.OnExpand. The callback fires once on first expand. Inside the callback, add child nodes dynamically from an API response and set IsLazy := false to prevent re-firing. The tree doesn’t know or care where the data comes from.

### Keyboard Navigation

The tree has tabindex="0" so it receives keyboard focus. Arrow Up/Down moves between visible nodes. Right expands or moves to first child. Left collapses or moves to parent. Enter/Space selects. Focus is tracked as an index into a computed flat list of currently visible nodes. This list is recalculated on every expand/collapse — a tree with a thousand nodes but only fifty visible computes a fifty-element list.

### Accessibility

The tree has role="tree". Each node has role="treeitem" with aria-expanded. Children containers have role="group". The focused node gets a visible outline ring. These attributes exist so screen readers can announce the tree structure, expansion state, and current position.

## Data Grid

JDataGrid is the most substantial component in the framework. It handles 100,000+ rows through virtual scrolling, supports column resize, inline cell editing, cell-level keyboard navigation, sorting, and clipboard copy. The API remains simple:

```pascal
Grid := JW3DataGrid.Create(Panel);
Grid.AddColumn('name', 'Name', 200, 'left', true, true);
Grid.AddColumn('email', 'Email', 280, 'left', true, true);
Grid.AddColumn('role', 'Role', 120);
Grid.SetData(LargeArray);
```

### Virtual Scrolling

The body wrapper contains a tall invisible sentinel div whose height equals rowCount × rowHeight. This creates a scrollbar proportional to the full dataset. Inside the body table, only the visible rows plus a buffer (default 10 above and below) are rendered. The table is translated vertically via CSS transform to align with the scroll position.

On each scroll event, the grid calculates the new visible range, compares to the currently rendered range, removes rows that left, and creates rows that entered. Rows are tracked in a JavaScript object keyed by view index for O(1) lookup. A dataset of 100,000 rows with 40px row height creates a 4,000,000px sentinel — well within browser limits — but only ~50 DOM elements exist at any time.

### Sorting

Click a column header to sort ascending. Click again for descending. Third click clears the sort and restores original order. The grid maintains two arrays: FData (original, never mutated) and FView (indices into FData, reordered by sort). Sorting uses JavaScript’s native Array.sort with localeCompare for strings and numeric comparison for numbers. Null values sort to the end.

### Column Resize

Each header cell has a 5px-wide absolutely-positioned resize handle at its right edge. On mousedown, the grid attaches mousemove/mouseup listeners on the document (not the handle) so dragging works even outside the header. A CSS class on the document body locks the cursor to col-resize during the drag. Minimum width is 50px per column. Both header and body colgroups update in real time.

### Inline Editing

Double-click a cell (or press Enter/F2) to enter edit mode, but only if the column’s Editable flag is true. The cell’s text is replaced by an \<input\> element. Enter commits, Escape cancels, Tab moves to the next editable cell. On commit, the data array is mutated and OnCellEdit fires with the old and new values. The application can validate, reject, or persist the change.

### Cell Focus and Clipboard

Arrow keys move between cells: Up/Down change rows, Left/Right change columns. Tab wraps at row boundaries. The focused cell gets a visible outline. Ctrl+C (Cmd+C on Mac) copies the focused cell’s text to the clipboard via the navigator.clipboard API.

### The Philosophy Holds

Even at this size, the data grid follows the framework’s principles. CSS variables control every visual aspect. ARIA roles provide accessibility. Virtual scrolling relies on the browser’s native scrollbar and CSS transform — no custom scrollbar reimplementation. Column widths use \<colgroup\>, not JavaScript pixel calculations. The grid does what the browser cannot do and delegates everything else.

#  Chapter 10: Non-Visual Components

## Not Everything Is a DOM Element

A database connection does not need a \<div\>. Inheriting from TElement for non-visual components would create hidden DOM elements for every service, every request, every model instance.

Non-visual components are plain Pascal classes. They inherit from TObject. They do not touch the DOM.

## Five Categories

**Services** — long-lived, often global. Database connections, authentication managers. Created once, used across forms.

**Async operations** — short-lived. HTTP requests, file reads. Created, started, cleaned up after callback. Often just a procedure with callbacks, not a class.

**Models** — data containers. Customer records, order lists. Plain classes with fields and validation.

**Adapters** — bridges between visual and non-visual. A list adapter connects a data array to a list component. It knows about both sides but inherits from neither.

**Stores** — observable state containers. DataStore is a key-value store where UI components subscribe to keys and update when values change. Put triggers notification to subscribers. BeginUpdate/EndUpdate batches notifications for bulk operations. The store bridges the gap between non-visual data and visual components without either side knowing about the other.

## The HTTP Helper

```pascal
FetchJSON('https://api.example.com/data',
procedure(Data: variant)
begin
// handle response
end,
procedure(Status: Integer; Msg: String)
begin
// handle error
end
);
```

Wraps XMLHttpRequest, parses JSON, routes to callbacks. A standalone procedure, not a component. PostJSON provides the same pattern for POST requests with a JSON body.

## Ownership

The developer creates and frees non-visual components. No automatic ownership system. For typical applications with a handful of services, manual management is explicit, predictable, and requires zero framework code.

#  Chapter 11: Node.js

## The Same Principle, Different Runtime

No DOM. No CSS. No `document`, no `window`. The browser core — `JElement`, `JForm`, `JApplication`, `Globals` — does not exist in a Node target. What exists is everything Node provides natively: HTTP, file system, OS, streams, timers, all accessible via `require`.

Shoestring on Node is a thin Pascal layer over those modules. The same compiler, the same language, the same anonymous-procedure callback style. Different API's.

## NodeTypes.pas

The single Node types unit declares the minimum set of externals a Node program needs:

```pascal
var Console external 'console': JConsole;
var JSON    external 'JSON':    TJSON;
var Global  external 'global':  variant;

function ReqNodeModule(id: string): variant; external 'require';
```

`ReqNodeModule` is same as `require`, but renamed because `require` is reserved in DWScript. Usage is identical though:

```pascal
var http := ReqNodeModule('http');
var os   := ReqNodeModule('os');
```

Everything else is plain Pascal.

Note : NoteTypes.pas will be expanded for additional externals when necessary.

## Entrypoint

```pascal
uses NodeHttpServer;
```

That is the complete entrypoint file. The `initialization` section of the named unit runs at startup. No `Application`, no `CreateForm`, no `GoToForm`.

## Minimal Unit

```pascal
unit NodeHello;

interface
uses NodeTypes;

implementation

initialization
  var os := ReqNodeModule('os');
  console.log('Platform: ' + String(os.platform()));
  console.log('Hostname: ' + String(os.hostname()));
  console.log('CPUs:     ' + String(os.cpus().length));
end.
```

```
node index.js
```

## HTTP Server

```pascal
unit NodeHttpServer;

interface
uses NodeTypes;

implementation

initialization
  var http := ReqNodeModule('http');
  var url  := ReqNodeModule('url');

  http.createServer(
    procedure(req, res: variant)
    var
      parsed:   variant;
      pathname: String;
      body:     String;
      code:     Integer;
    begin
      parsed   := url.parse(String(req.url), true);
      pathname := String(parsed.pathname);
      code     := 200;

      if pathname = '/' then
      begin
        var obj: variant := new JObject;
        obj.status  := 'ok';
        obj.message := 'Hello from Object Pascal on Node';
        body := JSON.Stringify(obj);
      end
      else
      begin
        code := 404;
        asm @body = JSON.stringify({ error: 'not found' }); end;
      end;

      asm res.writeHead(@code, { 'Content-Type': 'application/json' }); end;
      res.end(body);

      console.log(String(req.method) + ' ' + pathname + ' → ' + IntToStr(code));
    end

  ).listen(3000, procedure()
  begin
    console.log('Listening on port 3000');
  end);

end.
```

The request handler is an anonymous procedure — the same pattern as `OnClick` and `OnReady` in the browser target.

## Inline Assembly

Use asm blocks as per normal when Pascal syntax does not reach a JavaScript idiom or when it's just easier to use a javascript function:

```pascal
asm
  @body = JSON.stringify({
    utc:   new Date().toUTCString(),
    epoch: Date.now()
  });
end;
```

## Shared Units

Any unit with no dependency on `JElement`, `Globals`, `document`, or `window` compiles to both targets unchanged. `Validators.pas` is an example — pure string functions, no DOM, runs on both sides without modification. Data models and transformation logic belong in shared units for the same reason.

## Project Structure

```
app.entrypoint.pas               ← uses YourServerUnit
node/nodeCore/NodeTypes.pas      ← externals
node/YourServerUnit.pas          ← implementation
helpers/Validators.pas           ← target-agnostic units
```

Compile, run with `node index.js`.


#  Chapter 12: ShoeString in action

## Visual components

The following visual components are ready to go : see them in action in [the kitchen sink application.](https://lynkfs.com/docs/ss-v2)

## Page layouts

Examples of the 6 standard page layouts are included in [the layout-tab of the kitchensink.](https://lynkfs.com/docs/ss-v2)

## Non-visual components

The following non-visual components are ready to go : see them in action in [the nonvisual-tab of the kitchensink.](https://lynkfs.com/docs/ss-v2)

## Examples

Some more examples in [the examples-tab of the kitchensink.](https://lynkfs.com/docs/ss-v2)


#  Chapter 13: The Designer

Note: this chapter describes architecture and planned design. No designer code has been implemented. The application framework functions without a designer.

