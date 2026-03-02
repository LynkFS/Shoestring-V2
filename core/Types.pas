unit Types;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Types
//
//  External class bindings for browser APIs. These are typed interfaces
//  over JavaScript objects that already exist in the browser. At runtime
//  they cost nothing — no code is emitted. They give the Pascal compiler
//  enough type information to check calls at compile time.
//
//  This unit has no implementation section. Nothing to compile. Nothing
//  to execute. Pure declarations.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

type

  // ── Events ─────────────────────────────────────────────────────────────

  JEvent = class external 'Event'
  public
    &type:        String;
    target:       variant;
    key:          String;
    ctrlKey:      Boolean;
    shiftKey:     Boolean;
    metaKey:      Boolean;
    procedure stopPropagation;
    procedure preventDefault;
  end;

  TEventListener = procedure(Event: JEvent);

  JEventTarget = partial class external 'EventTarget'
  public
    procedure addEventListener(&type: String; callback: TEventListener;
      capture: Boolean = false); overload;
    procedure removeEventListener(&type: String; callback: TEventListener;
      capture: Boolean = false); overload;
  end;

  // ── DOM nodes ──────────────────────────────────────────────────────────

  JNode = class external 'Node' (JEventTarget)
  public
    parentNode:  JNode;
    firstChild:  JNode;
    childNodes:  variant;
    function  appendChild(node: JNode): JNode;
    function  removeChild(child: JNode): JNode;
    function  insertBefore(newNode, refNode: JNode): JNode;
  end;

  JElement = class external 'Element' (JNode)
  public
    id:           String;
    className:    String;
    innerHTML:    String;
    classList:    variant;
    scrollTop:    Integer;
    scrollLeft:   Integer;
    scrollHeight: Integer;
    scrollWidth:  Integer;
    offsetWidth:  Integer;
    offsetHeight: Integer;
    offsetTop:    Integer;
    offsetLeft:   Integer;
    textContent:  String;
    procedure setAttribute(name, value: String);
    function  getAttribute(name: String): String;
    procedure removeAttribute(name: String);
    function  hasAttribute(name: String): Boolean;
  end;

  JHTMLElement = partial class external 'HTMLElement' (JElement);

  // ── Style ──────────────────────────────────────────────────────────────

  JCSSStyleDeclaration = class external 'CSSStyleDeclaration'
  public
    function  getPropertyValue(propertyName: String): String;
    procedure setProperty(propertyName, value: String);
    procedure removeProperty(propertyName: String);
  end;

  JElementCSSInlineStyle = class external 'ElementCSSInlineStyle'
  public
    style: JCSSStyleDeclaration;
  end;

  // ── XMLHttpRequest ─────────────────────────────────────────────────────

  JXMLHttpRequest = class external 'XMLHttpRequest'
  public
    onreadystatechange: variant;
    responseText: String;
    readyState:   Integer;
    status:       Integer;
    statusText:   String;
    constructor Create;
    procedure open(&method, url: String); overload;
    procedure setRequestHeader(name, value: String);
    procedure send(data: variant); overload;
  end;

  // ── JSON ───────────────────────────────────────────────────────────────

  TJSON = class external 'JSON'
  public
    function Parse(Text: String): variant; overload; external 'parse';
    function Stringify(const Value: variant): String; overload; external 'stringify';
  end;

var
  JSON external 'JSON': TJSON;

implementation
end.
