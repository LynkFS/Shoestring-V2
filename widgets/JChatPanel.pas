unit JChatPanel;

// ─────────────────────────────────────────────────────────────────────────
//
//  JW3ChatPanel — bubble-style chat container.
//
//  Public API:
//    var Chat := JW3ChatPanel.Create(Parent);
//    Chat.AppendUser('Hello');
//    Chat.AppendAssistant('Hi there!');
//    Chat.ShowTyping;       // animated three-dot indicator
//    Chat.HideTyping;
//
//  Bubbles are click-to-copy: clicking a bubble copies its raw text
//  (not the rendered HTML) to the clipboard and flashes a 'copied' label.
//
//  Light markdown only — `**bold**` and newlines. By design.
//  Apps that want full markdown / syntax highlighting bring their own
//  parser (marked / micromark / highlight.js) and call SetHTML on the
//  bubble's DOM node themselves. Same "thin layer over primitives"
//  pattern as JFormulator.pas.
//
// ─────────────────────────────────────────────────────────────────────────

interface

uses JElement;

type
  JW3ChatPanel = class(TElement)
  private
    FTypingRow: TElement;
    procedure ScrollToBottom;
    procedure EnsureTypingRow;
    procedure AppendBubble(const Text: String; IsUser: Boolean);
  public
    constructor Create(Parent: TElement); virtual;
    procedure AppendUser(const Text: String);
    procedure AppendAssistant(const Text: String);
    procedure ShowTyping;
    procedure HideTyping;
  end;

implementation

uses Globals;

// ── Styles ────────────────────────────────────────────────────────────

var GJcpStyled: Boolean = false;

procedure RegisterJcpStyles;
begin
  if GJcpStyled then exit;
  GJcpStyled := true;
  AddStyleBlock(#'

    .jcp-chat {
      display: flex;
      flex-direction: column;
      gap: var(--space-2, 8px);
      padding: var(--space-3, 12px);
      overflow-y: auto;
      background: var(--surface-color, #ffffff);
      border: 1px solid var(--border-color, #e2e8f0);
      border-radius: var(--radius-md, 8px);
      min-height: 240px;
    }

    .jcp-row { display: flex; }
    .jcp-row-user { justify-content: flex-end; }
    .jcp-row-asst { justify-content: flex-start; }

    .jcp-bubble {
      max-width: 75%;
      padding: var(--space-2, 8px) var(--space-3, 12px);
      border-radius: var(--radius-lg, 12px);
      font-size: var(--text-sm, 14px);
      line-height: 1.55;
      white-space: pre-wrap;
      word-wrap: break-word;
      cursor: pointer;
      position: relative;
      user-select: text;
      transition: transform 0.05s var(--anim-ease, ease);
    }
    .jcp-bubble:active { transform: scale(0.99); }
    .jcp-bubble strong { font-weight: 700; }

    .jcp-bubble-user {
      background: var(--primary-color, #5c4ee3);
      color: #ffffff;
      border-bottom-right-radius: var(--radius-sm, 4px);
    }

    .jcp-bubble-asst {
      background: var(--surface-3, #eeeef2);
      color: var(--text-color, #1c1b21);
      border-bottom-left-radius: var(--radius-sm, 4px);
    }

    .jcp-copied {
      position: absolute;
      top: -18px;
      right: 4px;
      background: var(--text-color, #1c1b21);
      color: #ffffff;
      font-size: 11px;
      font-weight: 600;
      letter-spacing: 0.4px;
      padding: 2px 6px;
      border-radius: 3px;
      opacity: 0;
      pointer-events: none;
      transition: opacity 0.18s var(--anim-ease, ease);
      white-space: nowrap;
    }
    .jcp-bubble.jcp-copied-on .jcp-copied { opacity: 1; }

    .jcp-typing {
      display: inline-flex;
      align-items: center;
      gap: 4px;
      padding: var(--space-3, 12px) var(--space-3, 12px);
      background: var(--surface-3, #eeeef2);
      border-radius: var(--radius-lg, 12px);
      border-bottom-left-radius: var(--radius-sm, 4px);
    }
    .jcp-dot {
      width: 6px; height: 6px;
      border-radius: 50%;
      background: var(--text-light, #6b6a74);
      opacity: 0.4;
      animation: jcp-bounce 1.2s infinite;
    }
    .jcp-dot:nth-child(2) { animation-delay: 0.15s; }
    .jcp-dot:nth-child(3) { animation-delay: 0.30s; }
    @keyframes jcp-bounce {
      0%, 60%, 100% { transform: translateY(0);    opacity: 0.4; }
      30%           { transform: translateY(-4px); opacity: 1.0; }
    }

  ');
end;

// ── Light markdown: escape, bold, newlines ───────────────────────────

function FormatLightMd(const S: String): String;
var Out_: String;
begin
  Out_ := '';
  asm
    var t = @S;
    t = t.replace(/&/g, '&amp;')
         .replace(/</g, '&lt;')
         .replace(/>/g, '&gt;');
    t = t.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
    t = t.replace(/\n/g, '<br>');
    @Out_ = t;
  end;
  Result := Out_;
end;

// ── Lifecycle ────────────────────────────────────────────────────────

constructor JW3ChatPanel.Create(Parent: TElement);
begin
  inherited Create('div', Parent);
  RegisterJcpStyles;
  AddClass('jcp-chat');
  FTypingRow := nil;
end;

procedure JW3ChatPanel.ScrollToBottom;
var H: variant;
begin
  H := Handle;
  asm (@H).scrollTop = (@H).scrollHeight; end;
end;

// Lazily create the typing row once; show/hide via display: none/flex.
// Keeping a single instance avoids any "free child mid-life" question
// on the parent's child list.
procedure JW3ChatPanel.EnsureTypingRow;
var Bubble: TElement;
begin
  if FTypingRow <> nil then exit;

  FTypingRow := TElement.Create('div', Self);
  FTypingRow.AddClass('jcp-row');
  FTypingRow.AddClass('jcp-row-asst');

  Bubble := TElement.Create('div', FTypingRow);
  Bubble.AddClass('jcp-typing');

  TElement.Create('span', Bubble).AddClass('jcp-dot');
  TElement.Create('span', Bubble).AddClass('jcp-dot');
  TElement.Create('span', Bubble).AddClass('jcp-dot');

  FTypingRow.SetStyle('display', 'none');
end;

// ── One bubble ───────────────────────────────────────────────────────

procedure JW3ChatPanel.AppendBubble(const Text: String; IsUser: Boolean);
var
  Row:          TElement;
  Bubble:       TElement;
  Hint:         TElement;
  Html_:        String;
  RawText:      String;
  BubbleHandle: variant;
  PaneHandle:   variant;
  TypingHandle: variant;
begin
  Row := TElement.Create('div', Self);
  Row.AddClass('jcp-row');
  if IsUser then Row.AddClass('jcp-row-user')
            else Row.AddClass('jcp-row-asst');

  Bubble := TElement.Create('div', Row);
  Bubble.AddClass('jcp-bubble');
  if IsUser then Bubble.AddClass('jcp-bubble-user')
            else Bubble.AddClass('jcp-bubble-asst');

  // Render light markdown into innerHTML, then add the (separate) copy-hint.
  Html_ := FormatLightMd(Text);
  Bubble.SetHTML(Html_);

  Hint := TElement.Create('div', Bubble);
  Hint.AddClass('jcp-copied');
  Hint.SetText('copied');

  // Click → copy raw text (not innerHTML), flash the hint for ~900ms.
  RawText      := Text;
  BubbleHandle := Bubble.Handle;
  asm
    (@BubbleHandle).addEventListener('click', function(){
      try { navigator.clipboard.writeText(@RawText); } catch(e) {}
      (@BubbleHandle).classList.add('jcp-copied-on');
      setTimeout(function(){
        (@BubbleHandle).classList.remove('jcp-copied-on');
      }, 900);
    });
  end;

  // If the typing row is currently showing, move it back to the end of
  // the DOM so it stays beneath the latest message. appendChild on an
  // existing child is a move, not a duplicate.
  if FTypingRow <> nil then
  begin
    PaneHandle   := Handle;
    TypingHandle := FTypingRow.Handle;
    asm (@PaneHandle).appendChild(@TypingHandle); end;
  end;

  ScrollToBottom;
end;

// ── Public ───────────────────────────────────────────────────────────

procedure JW3ChatPanel.AppendUser(const Text: String);
begin
  AppendBubble(Text, true);
end;

procedure JW3ChatPanel.AppendAssistant(const Text: String);
begin
  AppendBubble(Text, false);
end;

procedure JW3ChatPanel.ShowTyping;
begin
  EnsureTypingRow;
  FTypingRow.SetStyle('display', 'flex');
  ScrollToBottom;
end;

procedure JW3ChatPanel.HideTyping;
begin
  if FTypingRow <> nil then
    FTypingRow.SetStyle('display', 'none');
end;

end.
