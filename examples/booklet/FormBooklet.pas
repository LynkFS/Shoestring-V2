unit FormBooklet;

// ═══════════════════════════════════════════════════════════════════════════
//
//  FormBooklet
//
//  A Shoestring form using the Document layout to display the Shoestring
//  booklet. The aside panel (left) shows a table of contents. The content
//  panel (right) shows all chapters with sections. Clicking a TOC entry
//  scrolls the content panel to that chapter.
//
//  Structure:
//
//    Self (TW3Form)
//      └── Shell        .doc-shell
//            ├── Header  .doc-header
//            ├── Body    .doc-body
//            │     ├── Aside   .doc-aside    (TOC, scrolls independently)
//            │     └── Content .doc-content  (chapters, scrollable)
//
//  Notes:
//
//    - The aside is created before content so it appears on the left.
//      LayoutDocument puts them in a flex row; source order = visual order.
//    - Chapter panels are stored in FChapterPanels[] for scroll targeting.
//    - TOC items are stored in FTocItems[] for active-state management.
//    - ScrollIntoView is called via asm on the chapter panel's Handle.
//    - The content panel needs overflow-y:auto and the aside needs
//      a left border instead of the default right border from the layout.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement, JForm, JPanel, LayoutDocument, BookletStyles;

type
  TFormBooklet = class(TW3Form)
  private
    Shell:   JW3Panel;
    Header:  JW3Panel;
    Body:    JW3Panel;
    Aside:   JW3Panel;
    Content: JW3Panel;

    FChapterPanels: array of JW3Panel;
    FTocItems:      array of JW3Panel;
    FActiveToc:     Integer;

    procedure BuildHeader;
    procedure BuildToc;
    procedure BuildChapters;

    procedure AddChapter(Index: Integer; const Title: String;
      const Sections: array of array of String);

    procedure AddSection(Parent: JW3Panel; const Heading, BodyText: String);
    procedure ParseBody(Parent: JW3Panel; const Text: String);

    procedure HandleTocClick(Sender: TObject);
    procedure SetActiveToc(Index: Integer);
    procedure ScrollToChapter(Index: Integer);

  protected
    procedure InitializeObject; override;
  end;

implementation

uses Globals;


{ TFormBooklet }

procedure TFormBooklet.InitializeObject;
begin
  inherited;

  // ── Document layout structure ──────────────────────────────────────

  Shell := JW3Panel.Create(Self);
  Shell.AddClass(csDocShell);

  Header := JW3Panel.Create(Shell);
  Header.AddClass(csDocHeader);

  Body := JW3Panel.Create(Shell);
  Body.AddClass(csDocBody);
  // Override: don't center, let aside sit left and content fill right
  Body.SetStyle('justify-content', 'flex-start');

  // Aside first in source order = left visually in flex-row
  Aside := JW3Panel.Create(Body);
  Aside.AddClass(csDocAside);
  // Override: border on right side (sidebar is on the left)
  Aside.SetStyle('border-right', '1px solid var(--border-color, #e2e8f0)');
  Aside.SetStyle('overflow-y', 'auto');

  Content := JW3Panel.Create(Body);
  Content.AddClass(csDocContent);
  // Content scrolls independently
  Content.SetStyle('overflow-y', 'auto');
  Content.SetStyle('padding-bottom', '120px');
  Content.SetStyle('scroll-behavior', 'smooth');

  FActiveToc := -1;

  // ── Populate ───────────────────────────────────────────────────────

  BuildHeader;
  BuildToc;
  BuildChapters;

  // Activate first chapter in TOC
  if FTocItems.Count > 0 then
    SetActiveToc(0);
end;


//=============================================================================
// Header
//=============================================================================

procedure TFormBooklet.BuildHeader;
begin
  var Logo := JW3Panel.Create(Header);
  Logo.SetText('Shoestring');
  Logo.SetStyle('font-weight', '700');
  Logo.SetStyle('font-size', '1.1rem');
  Logo.SetStyle('color', 'var(--primary-color, #6366f1)');

  var Sub := JW3Panel.Create(Header);
  Sub.SetText('A Minimalist Web Framework in Object Pascal');
  Sub.SetStyle('font-size', '0.8rem');
  Sub.SetStyle('color', 'var(--text-light, #64748b)');
end;


//=============================================================================
// Table of Contents (sidebar)
//=============================================================================

procedure TFormBooklet.BuildToc;
const
  Titles: array of String = [
    'Origins',
    'The Async Nature of the Web',
    'Positioning',
    'Styling and Theming',
    'Layout',
    'Typography',
    'Forms and Validation',
    'Building Components',
    'The Designer',
    'Non-Visual Components',
    'Node.js'
  ];
begin
  var TocLabel := JW3Panel.Create(Aside);
  TocLabel.AddClass(csTocLabel);
  TocLabel.SetText('Contents');

  for var i := 0 to Titles.Count - 1 do
  begin
    var Item := JW3Panel.Create(Aside);
    Item.AddClass(csTocItem);
    Item.SetText(IntToStr(i + 1) + '.  ' + Titles[i]);
    Item.Tag := IntToStr(i);
    Item.OnClick := HandleTocClick;
    FTocItems.Add(Item);
  end;
end;


//=============================================================================
// Chapters
//=============================================================================

procedure TFormBooklet.BuildChapters;
begin

  // ── Chapter 1: Origins ─────────────────────────────────────────────

  AddChapter(0, 'Origins', [
    ['The Itch',
     'About five years ago, I started building a web framework. Not because the world needed another one, but because the ones I had were doing too much.' + #10 +
     'I was working with Smart Mobile Studio, a compiler that translates Object Pascal to JavaScript. SMS is a capable system with a rich component library, a visual designer, and a runtime that abstracts the browser into something resembling a traditional desktop application. Its successor, QTX (Quartex Pascal), carries that tradition forward with modern tooling and an active development community.' + #10 +
     'But I kept noticing something. The runtime library was reimplementing things the browser already knew how to do. Layout algorithms that recalculated pixel positions on resize, even though CSS flexbox handles that natively. Theme engines that generated inline styles, even though CSS custom properties let you change a single variable and watch every component update instantly.' + #10 +
     'Each of these features was well-engineered. Each solved a real problem. And each was unnecessary.' + #10 +
     'Shoestring has a different goal: to provide the thinnest possible typed layer over the browser itself.' + #10 +
     '[quote]Nothing during the development gave me more satisfaction than deleting chunks of code which were not absolutely necessary.[/quote]'],

    ['The Principle',
     'The guiding rule is simple: if the browser does it, don''t.' + #10 +
     'When a traditional framework creates a button, it might include properties for background colour, hover colour, border radius, font size, and a dozen other attributes. A button can reach 200 lines before it does anything useful. In Shoestring, a button is this:' + #10 +
     '[code]constructor TButton.Create(Parent: TElement);' + #10 +
     'begin' + #10 +
     '  inherited Create(''button'', Parent);' + #10 +
     '  AddClass(''btn'');' + #10 +
     'end;[/code]' + #10 +
     'Five lines. The visual appearance, hover state, focus ring, and transitions are all in a CSS class. CSS is purpose-built for visual presentation. Reimplementing it in Pascal means writing code that is worse than CSS at being CSS.'],

    ['Why Not a Competitor to QTX',
     'Both frameworks compile Object Pascal to JavaScript. Both create DOM elements. The difference is in what they provide between Pascal and the browser.' + #10 +
     'QTX provides a complete abstraction layer: visual designer, property cache, state machine, theme engine, hundreds of runtime units.' + #10 +
     'Shoestring provides typed access to the browser. No designer dependency, no property cache, no state machine. Pascal methods map one-to-one to CSS properties and DOM methods.' + #10 +
     'A QTX developer learns QTX. A Shoestring developer learns CSS and the DOM. Neither approach is superior. They serve different priorities.'],

    ['The Core',
     'The entire framework compiles from five units. Everything descends from TElement, which wraps an HTML element.' + #10 +
     'Types.pas — external class bindings for browser APIs. At runtime, they cost nothing.' + #10 +
     'JElement.pas — TElement, the ancestor of everything. About 300 lines.' + #10 +
     'JForm.pas — TW3Form. About 50 lines.' + #10 +
     'JApplication.pas — form navigation with state preservation. About 60 lines.' + #10 +
     'Globals.pas — externals, stylesheet, theme variables, application init. About 120 lines.' + #10 +
     'Five units. Roughly 560 lines of Pascal. That is the entire framework.'],

    ['The Minimal Application',
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
     'Compile with QTX. Drop the JavaScript into an index.html. One Pascal file, one HTML file, one compiled JavaScript file.']
  ]);

  // ── Chapter 2: Async ───────────────────────────────────────────────

  AddChapter(1, 'The Async Nature of the Web', [
    ['The Problem',
     'In a desktop application, when you create a button and set its width to 200 pixels, it is 200 pixels wide immediately. In a browser, this is not true.' + #10 +
     'When you call document.createElement, the browser creates an element in memory. When you call appendChild, it enters the DOM. But the browser has not yet calculated its size. Read offsetWidth immediately and you may get zero.' + #10 +
     'Every web framework must answer: when is a widget ready?'],

    ['Four Approaches',
     'Promise + WhenReady (QTX): State machine with property cache. Complete but heavyweight — doubles component code.' + #10 +
     'MutationObserver: Watches parent''s childList. Must observe before appendChild or the callback never fires. Silent failure.' + #10 +
     'Promise.resolve() microtask: Simpler, same timing. But layout isn''t computed.' + #10 +
     'requestAnimationFrame: Fires before the next repaint. Browser computes layout first. offsetWidth returns the real value.'],

    ['The Choice',
     'Shoestring uses requestAnimationFrame. One line in the constructor:' + #10 +
     '[code]window.requestAnimationFrame(ElementReady);[/code]' + #10 +
     'No observer setup. No cleanup. No ordering dependency. The callback fires once, after layout is computed. The tradeoff is up to ~16ms delay — imperceptible for widget construction.']
  ]);

  // ── Chapter 3: Positioning ─────────────────────────────────────────

  AddChapter(2, 'Positioning', [
    ['Flex by Default',
     'Every TElement is created with display:flex and flex-direction:column. This is the single most important design decision in the framework.' + #10 +
     'Children stack vertically. No positioning code needed.' + #10 +
     '[code]var Header  := JW3Panel.Create(Self);' + #10 +
     'Header.Height := 48;' + #10 +
     '' + #10 +
     'var Content := JW3Panel.Create(Self);' + #10 +
     'Content.SetGrow(1);' + #10 +
     '' + #10 +
     'var Footer  := JW3Panel.Create(Self);' + #10 +
     'Footer.Height := 24;[/code]' + #10 +
     'Header-content-footer with zero positioning logic. Resize the browser and the content adjusts automatically.'],

    ['Why Not Left/Top/SetBounds?',
     'The original had these on every element. In a flex container, left and top are ignored unless position is absolute. Since every element defaulted to flex, these properties did nothing.' + #10 +
     'The redesign removes them. If a component needs absolute positioning, it uses SetStyle.'],

    ['Horizontal and Grid',
     'For horizontal layout: SetStyle(''flex-direction'', ''row''). For two-dimensional: SetStyle(''display'', ''grid''). The framework provides SetStyle for both. It does not provide layout manager classes.']
  ]);

  // ── Chapter 4: Styling and Theming ─────────────────────────────────

  AddChapter(3, 'Styling and Theming', [
    ['Three Ways to Style',
     'SetStyle writes to element.style (inline). Highest specificity. Use for runtime-dynamic values.' + #10 +
     'SetRule and SetRulePseudo write to the framework stylesheet. Use for pseudo-class states like :hover and :focus.' + #10 +
     'AddClass assigns a CSS class defined via AddStyleBlock. Use for static appearance shared across instances. This is the primary mechanism.'],

    ['CSS Variables as Design Tokens',
     'Colours: --primary-color, --text-color, --bg-color, --surface-color.' + #10 +
     'Spacing: --space-1 (4px) through --space-16 (64px). Consistent rhythm.' + #10 +
     'Border radius: --radius-sm through --radius-full.' + #10 +
     'Elevation: --shadow-sm through --shadow-lg.' + #10 +
     'Animation: --anim-duration. Change once, every transition adjusts.'],

    ['Dark Mode and Interaction States',
     'Dark mode is a second set of variable values on :root.dark. Toggle one class, every component updates instantly.' + #10 +
     'A shared .interactive class provides hover, focus, active, and disabled states. Any clickable component adds it and gets all four.'],

    ['Style Units',
     'Styles are organised into Pascal units. Each exports string constants for class names (compile-time safety), registers CSS via AddStyleBlock, and auto-initialises. Import the unit, get the styles.']
  ]);

  // ── Chapter 5: Layout ──────────────────────────────────────────────

  AddChapter(4, 'Layout', [
    ['The Layout Hierarchy',
     'Media queries define page state: mobile versus desktop.' + #10 +
     'CSS Grid defines slots where components live.' + #10 +
     'Container queries define how a component looks inside its slot.' + #10 +
     'Flexbox handles alignment inside a component.' + #10 +
     'This is a decision guide, not a mandatory stack. Most elements use one or two of these.'],

    ['Layout Units',
     'Six pre-built patterns as CSS class collections:' + #10 +
     'Dashboard — sidebar, header, auto-filling card grid.' + #10 +
     'Document — fixed header, centered content column, optional sidebar.' + #10 +
     'Split — two equal or weighted panels.' + #10 +
     'Holy Grail — header, footer, three columns.' + #10 +
     'Stacked — header, vertical sections, footer.' + #10 +
     'Kanban — header plus horizontal scrolling columns.'],

    ['Responsive Without Resize Events',
     'Window resize listeners are removed from TElement. Only TW3Form listens for resize. Responsiveness is handled by CSS: media queries shift grid structure, flex containers wrap, container queries adapt components.']
  ]);

  // ── Chapter 6: Typography ──────────────────────────────────────────

  AddChapter(5, 'Typography', [
    ['Fluid Scaling',
     'The base font size scales with the viewport using CSS clamp():' + #10 +
     '[code]:root { font-size: clamp(15px, 1vw + 12px, 18px); }[/code]' + #10 +
     'On a 375px phone: ~15.75px. On a 1440px desktop: ~17px. No media queries. One declaration and every rem value scales proportionally.'],

    ['The Type Scale and Prose',
     '[code]Title.AddClass(''text-3xl'');' + #10 +
     'Title.AddClass(''font-bold'');' + #10 +
     'Body.AddClass(''text-prose'');[/code]' + #10 +
     'The prose class caps line length at 65 characters, sets relaxed line height, enables word wrapping and hyphenation. It protects readability regardless of container width.']
  ]);

  // ── Chapter 7: Forms and Validation ────────────────────────────────

  AddChapter(6, 'Forms and Validation', [
    ['The Field Base',
     'Every form element needs a label, a value, a change event, and validation state. A shared CSS class defines the common visual identity:' + #10 +
     '[code].field {' + #10 +
     '  height: var(--field-height, 40px);' + #10 +
     '  padding: 0 var(--space-3);' + #10 +
     '  border: 1px solid var(--border-color);' + #10 +
     '  border-radius: var(--radius-md);' + #10 +
     '}' + #10 +
     '.field:focus { border-color: var(--primary-color); }' + #10 +
     '.field.invalid { border-color: var(--color-danger); }[/code]' + #10 +
     'Every form component adds AddClass(''field''). Change --field-height on :root and every field adjusts.'],

    ['Values, Events, and Validation',
     'Form components read/write the DOM element directly. No backing field. The browser is the single source of truth.' + #10 +
     'Validation is pure functions: IsRequired, IsEmail, MinLength:' + #10 +
     '[code]if not IsRequired(FEmail.Value) then' + #10 +
     '  FEmail.AddClass(''invalid'')' + #10 +
     'else' + #10 +
     '  FEmail.RemoveClass(''invalid'');[/code]' + #10 +
     'The class triggers styling. The function provides logic. The component provides the value.']
  ]);

  // ── Chapter 8: Building Components ─────────────────────────────────

  AddChapter(7, 'Building Components', [
    ['The Pattern',
     'Every component follows a three-part pattern:' + #10 +
     'A style unit registers CSS classes via AddStyleBlock. All visual definitions live here.' + #10 +
     'A Pascal class inherits from TElement. The constructor creates the HTML element, adds the CSS class, wires events.' + #10 +
     'String constants for class names give compile-time safety. A typo in csTabsBtn fails at compile time.' + #10 +
     'The discipline: if the constructor exceeds ten lines, something that should be in CSS is probably in Pascal.'],

    ['What Components Do Not Do',
     'Components do not manage their own themes — they reference CSS variables.' + #10 +
     'Components do not handle their own responsive behaviour — they use flexbox defaults or layout classes.' + #10 +
     'Components do not validate their own input — they expose values and fire events.' + #10 +
     'Each thing is done by the tool best suited to do it.']
  ]);

  // ── Chapter 9: The Designer ────────────────────────────────────────

  AddChapter(8, 'The Designer', [
    ['Scaffold Generator, Not Runtime Dependency',
     'In QTX, the designer produces QFM files that the runtime loads. The application depends on the designer''s output format.' + #10 +
     'In Shoestring, the designer produces Pascal source code. The output is a .pas file that compiles like any other unit. Delete the designer and the application still compiles.' + #10 +
     '[code]Designer (.design) -> .pas file -> Compiler -> Browser[/code]'],

    ['Round-Tripping and Export',
     'Generated code uses guarded regions. The designer reads and writes within markers. Developer code outside is preserved.' + #10 +
     'Two export modes: HTML mode exports a complete page for web designers. Pascal mode exports a framework-compatible unit. Both use the same AddClass, SetStyle, and constructors.']
  ]);

  // ── Chapter 10: Non-Visual Components ──────────────────────────────

  AddChapter(9, 'Non-Visual Components', [
    ['Not Everything Is a DOM Element',
     'A database connection does not need a div. Inheriting from TElement would create hidden DOM elements for every service and model.' + #10 +
     'Non-visual components are plain Pascal classes. They inherit from TObject. They do not touch the DOM.'],

    ['Four Categories',
     'Services — long-lived, often global. Database connections, authentication managers.' + #10 +
     'Async operations — short-lived. HTTP requests. Often just a procedure with callbacks.' + #10 +
     'Models — data containers. Plain classes with fields and validation.' + #10 +
     'Adapters — bridges between visual and non-visual.'],

    ['The HTTP Helper',
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
     'Wraps XMLHttpRequest, parses JSON, routes to callbacks. A standalone procedure, not a component.']
  ]);

  // ── Chapter 11: Node.js ────────────────────────────────────────────

  AddChapter(10, 'Node.js', [
    ['The Compiler Output Is JavaScript',
     'DWScript compiles Object Pascal to JavaScript. That JavaScript targets the browser. Node.js has none of the browser APIs. But the compiled output is still JavaScript.' + #10 +
     'Not all Shoestring code depends on the browser. Data models, validation, JSON serialisation are pure computation. Separate the browser-dependent code and the rest runs anywhere JavaScript runs.'],

    ['Separate Entry Points, Shared Logic',
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
     'Shared units never import browser-specific units. The discipline is simple.'],

    ['What This Enables',
     'Shared models mean the browser and server validate data with the same code. Change a rule once, both sides update.' + #10 +
     'Shared business logic means calculations are written once and run on the client for responsiveness and on the server for authoritative processing.' + #10 +
     'This is the practical consequence of compiling Pascal to JavaScript and being disciplined about which units import the DOM.']
  ]);
end;


//=============================================================================
// AddChapter — creates a chapter container with number, title, and sections
//=============================================================================

procedure TFormBooklet.AddChapter(Index: Integer; const Title: String;
  const Sections: array of array of String);
var
  Ch: JW3Panel;
begin
  // Divider between chapters (not before the first)
  if Index > 0 then
  begin
    var Div := JW3Panel.Create(Content);
    Div.AddClass(csDivider);
  end;

  // Chapter container
  Ch := JW3Panel.Create(Content);
  Ch.AddClass(csChapter);
  FChapterPanels.Add(Ch);

  // Chapter number label
  var Num := JW3Panel.Create(Ch);
  Num.AddClass(csChapterNumber);
  Num.SetText('Chapter ' + IntToStr(Index + 1));

  // Chapter title
  var TitlePanel := JW3Panel.Create(Ch);
  TitlePanel.AddClass(csChapterTitle);
  TitlePanel.SetText(Title);

  // Sections
  for var i := 0 to Sections.Count - 1 do
  begin
    var Sec := Sections[i];
    if Sec.Count >= 2 then
      AddSection(Ch, Sec[0], Sec[1]);
  end;
end;


//=============================================================================
// AddSection — heading + parsed body text
//=============================================================================

procedure TFormBooklet.AddSection(Parent: JW3Panel;
  const Heading, BodyText: String);
begin
  var Sec := JW3Panel.Create(Parent);
  Sec.AddClass(csSection);

  var H := JW3Panel.Create(Sec);
  H.AddClass(csSectionTitle);
  H.SetText(Heading);

  ParseBody(Sec, BodyText);
end;


//=============================================================================
// ParseBody — splits text on #10, handles [code]...[/code] and
//             [quote]...[/quote] markers
//=============================================================================

procedure TFormBooklet.ParseBody(Parent: JW3Panel; const Text: String);
var
  Lines: array of String;
  i: Integer;
  InCode: Boolean;
  CodeBuf: String;
begin
  // Split on line feed
  Lines := Text.Split(#10);
  InCode := false;
  CodeBuf := '';

  for i := 0 to Lines.Count - 1 do
  begin
    var Line := Lines[i];

    // ── Code block start ──────────────────────────────────────────
    if (not InCode) and (Pos('[code]', Line) > 0) then
    begin
      // Text before [code] on same line
      var Before := Copy(Line, 1, Pos('[code]', Line) - 1);
      if Before <> '' then
      begin
        var P := JW3Panel.Create(Parent);
        P.AddClass(csBodyText);
        P.SetText(Before);
      end;

      // Check if [/code] is on the same line
      var After := Copy(Line, Pos('[code]', Line) + 6, Length(Line));
      if Pos('[/code]', After) > 0 then
      begin
        // Single-line code block
        var CodeText := Copy(After, 1, Pos('[/code]', After) - 1);
        var CB := JW3Panel.Create(Parent);
        CB.AddClass(csCodeBlock);
        CB.SetText(CodeText);
      end
      else
      begin
        InCode := true;
        CodeBuf := After;
      end;
    end

    // ── Code block end ────────────────────────────────────────────
    else if InCode then
    begin
      if Pos('[/code]', Line) > 0 then
      begin
        var Before := Copy(Line, 1, Pos('[/code]', Line) - 1);
        if CodeBuf <> '' then
          CodeBuf := CodeBuf + #10 + Before
        else
          CodeBuf := Before;

        var CB := JW3Panel.Create(Parent);
        CB.AddClass(csCodeBlock);
        CB.SetText(CodeBuf);
        CodeBuf := '';
        InCode := false;
      end
      else
      begin
        if CodeBuf <> '' then
          CodeBuf := CodeBuf + #10 + Line
        else
          CodeBuf := Line;
      end;
    end

    // ── Quote ─────────────────────────────────────────────────────
    else if (Pos('[quote]', Line) > 0) then
    begin
      var QText := Line;
      QText := Copy(QText, Pos('[quote]', QText) + 7, Length(QText));
      if Pos('[/quote]', QText) > 0 then
        QText := Copy(QText, 1, Pos('[/quote]', QText) - 1);

      var Q := JW3Panel.Create(Parent);
      Q.AddClass(csQuote);
      Q.SetText(QText);
    end

    // ── Regular paragraph ─────────────────────────────────────────
    else if Line <> '' then
    begin
      var P := JW3Panel.Create(Parent);
      P.AddClass(csBodyText);
      P.SetText(Line);
    end;
  end;
end;


//=============================================================================
// TOC click handling
//=============================================================================

procedure TFormBooklet.HandleTocClick(Sender: TObject);
var
  Index: Integer;
begin
  Index := StrToInt(TElement(Sender).Tag);
  SetActiveToc(Index);
  ScrollToChapter(Index);
end;

procedure TFormBooklet.SetActiveToc(Index: Integer);
begin
  // Remove active from previous
  if (FActiveToc >= 0) and (FActiveToc < FTocItems.Count) then
    FTocItems[FActiveToc].RemoveClass(csTocActive);

  // Set new active
  FActiveToc := Index;
  if (Index >= 0) and (Index < FTocItems.Count) then
    FTocItems[Index].AddClass(csTocActive);
end;

procedure TFormBooklet.ScrollToChapter(Index: Integer);
var
  mHandle: variant;
begin
  if (Index < 0) or (Index >= FChapterPanels.Count) then exit;

  mHandle := FChapterPanels[Index].Handle;
  asm
    (@mHandle).scrollIntoView({ behavior: 'smooth', block: 'start' });
  end;
end;

end.
