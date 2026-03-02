unit Globals;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Globals
//
//  Browser externals, framework globals, style injection, ID generation,
//  and application creation.
//
//  This unit provides infrastructure only. It does NOT declare theme
//  variables — those live in ThemeStyles. It does NOT declare font-size
//  scales — those live in TypographyStyles. The separation is intentional:
//  Globals is the plumbing. Style units are the design.
//
//  The framework stylesheet (styleSheet) exists for SetRule/SetRulePseudo
//  which insert rules targeting elements by their unique ID. This is
//  separate from AddStyleBlock which creates <style> elements for class-
//  based CSS. Both are valid; SetRule is for runtime-dynamic per-element
//  rules, AddStyleBlock is for static shared styles.
//
//  Initialization order:
//    1. Screen dimensions captured
//    2. Framework stylesheet created (for SetRule)
//    3. Body defaults applied (minimal, no theme dependency)
//    4. Application instance created
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JApplication, Types, JElement;

// ── Browser externals ────────────────────────────────────────────────────

var document external 'document': variant;
var window   external 'window':   variant;
var console  external 'console':  variant;

// ── Framework globals ────────────────────────────────────────────────────

var Application:  JW3Application;
var ScreenWidth:  Integer := 0;
var ScreenHeight: Integer := 0;
var styleSheet:   variant;

// ── ID generation ────────────────────────────────────────────────────────

type
  TW3Identifiers = static class
  private
    class var FCounter: Integer;
  public
    class function GenerateUniqueObjectId: String;
  end;

// ── Style injection ──────────────────────────────────────────────────────

procedure AddStyleBlock(const CSS: String);


implementation


//=============================================================================
// Style injection
//=============================================================================

procedure AddStyleBlock(const CSS: String);
var
  el: variant;
begin
  el := document.createElement('style');
  asm (@el).textContent = @CSS; end;
  document.head.appendChild(el);
end;


//=============================================================================
// ID generation
//=============================================================================

class function TW3Identifiers.GenerateUniqueObjectId: String;
begin
  inc(FCounter);
  Result := 'el' + FCounter.ToString;
end;


//=============================================================================
// Initialization
//=============================================================================

initialization

  ScreenWidth  := window.innerWidth;
  ScreenHeight := window.innerHeight;

  // ── Framework stylesheet — for SetRule (per-element ID rules) ──────

  var styleEl: variant := document.createElement('style');
  document.head.appendChild(styleEl);
  styleSheet := styleEl.sheet;

  // ── Body defaults — minimal, no theme variables ───────────────────

  AddStyleBlock(#'
    html, body {
      height: 100%;
    }
    *, *::before, *::after {
      box-sizing: border-box;
    }
    body {
      margin: 0;
      padding: 0;
      overflow: hidden;
      overscroll-behavior: none;
      font-family: system-ui, -apple-system, "Segoe UI", Roboto,
                   "Helvetica Neue", Arial, sans-serif;
      line-height: 1.5;
      -webkit-font-smoothing: antialiased;
    }

    /* ── Base class for all TElement instances ───────────────────── */
    /* Applied by the constructor. Replaces inline styles so that   */
    /* component CSS classes can override without specificity wars.  */

    .ss-base {
      display: flex;
      flex-direction: column;
    }
  ');

  // ── Application — created last ────────────────────────────────────

  Application := JW3Application.Create(nil);

end.