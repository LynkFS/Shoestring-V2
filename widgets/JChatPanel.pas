unit JChatPanel;

// ─────────────────────────────────────────────────────────────────────────
//
//  JW3ChatPanel — bubble-style chat container.
//
//  Public API:
//    var Chat := JW3ChatPanel.Create(Parent);
//
//    // whole-message (unchanged from v1)
//    Chat.AppendUser('Hello');
//    Chat.AppendAssistant('Hi there!');
//    Chat.ShowTyping;       // animated three-dot indicator
//    Chat.HideTyping;
//
//    // streaming  (new)
//    var Span := Chat.BeginAssistant;            // empty bubble, typing hidden
//    Chat.AppendAssistantChunk(Span, 'Hello, ');
//    Chat.AppendAssistantChunk(Span, 'world.');  // append text deltas
//    Chat.FinishAssistant(Span);                 // final markdown + click-to-copy
//
//  Bubbles are click-to-copy: clicking a bubble copies its raw text
//  (not the rendered HTML) to the clipboard and flashes a 'copied' label.
//  For streaming bubbles, "raw text" means the accumulated stream at the
//  moment of the click.
//
//  Light markdown only — `**bold**` and newlines. By design.
//  Apps that want full markdown / syntax highlighting bring their own
//  parser (marked / micromark / highlight.js) and call SetHTML on the
//  content span themselves. The span returned by BeginAssistant is that
//  surface — apps can take it over and we will not fight them.
//  Same "thin layer over primitives" pattern as JFormulator.pas.
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
    // Streaming primitives
    function  CreateStreamingBubble: TElement;     // returns content span
    procedure AttachCopyHandler(Bubble: TElement);
  public
    constructor Create(Parent: TElement); virtual;

    // Whole-message API (v1, unchanged)
    procedure AppendUser(const Text: String);
    procedure AppendAssistant(const Text: String);
    procedure ShowTyping;
    procedure HideTyping;

    // Streaming API (v2)
    function  BeginAssistant: TElement;
    procedure AppendAssistantChunk(ContentSpan: TElement; const Delta: String);
    procedure FinishAssistant(ContentSpan: TElement);

    // Clear all messages and the typing indicator, returning the panel to
    // its just-created state. Streaming spans handed out before Reset are
    // void afterwards — discard them.
    procedure Reset;
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

    /* Subtle caret hint while a stream is in flight.                  */
    /* Removed when FinishAssistant is called.                         */
    .jcp-streaming::after {
      content: "▍";
      display: inline-block;
      margin-left: 2px;
      opacity: 0.6;
      animation: jcp-caret 1s steps(2) infinite;
    }
    @keyframes jcp-caret { 50% { opacity: 0; } }

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

// ── Click-to-copy ────────────────────────────────────────────────────
//
//  Both whole-message and streamed bubbles share this. The handler
//  reads the current text from the bubble's `_jcpText` JS property
//  at click time, so for a streaming bubble the user always copies
//  whatever has accumulated so far - including text added after the
//  handler was attached.

procedure JW3ChatPanel.AttachCopyHandler(Bubble: TElement);
var
  Hint: TElement;
  BubbleHandle: variant;
begin
  // Add the visual "copied" hint inside the bubble.
  Hint := TElement.Create('div', Bubble);
  Hint.AddClass('jcp-copied');
  Hint.SetText('copied');

  BubbleHandle := Bubble.Handle;
  asm
    (@BubbleHandle).addEventListener('click', function(){
      var raw = (@BubbleHandle)._jcpText || '';
      try { navigator.clipboard.writeText(raw); } catch(e) {}
      (@BubbleHandle).classList.add('jcp-copied-on');
      setTimeout(function(){
        (@BubbleHandle).classList.remove('jcp-copied-on');
      }, 900);
    });
  end;
end;

// ── One bubble (whole-message path, v1 unchanged in spirit) ──────────

procedure JW3ChatPanel.AppendBubble(const Text: String; IsUser: Boolean);
var
  Row:          TElement;
  Bubble:       TElement;
  Content:      TElement;
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

  // Render light markdown into a content span (not the bubble itself),
  // so the click-to-copy hint stays a separate sibling and so the
  // streaming and whole-message paths share the same DOM shape.
  Content := TElement.Create('span', Bubble);
  Html_   := FormatLightMd(Text);
  Content.SetHTML(Html_);

  // Stash raw text on the bubble DOM node for the click handler.
  RawText      := Text;
  BubbleHandle := Bubble.Handle;
  asm (@BubbleHandle)._jcpText = @RawText; end;

  AttachCopyHandler(Bubble);

  // Keep the typing row beneath the latest message if it is visible.
  if FTypingRow <> nil then
  begin
    PaneHandle   := Handle;
    TypingHandle := FTypingRow.Handle;
    asm (@PaneHandle).appendChild(@TypingHandle); end;
  end;

  ScrollToBottom;
end;

// ── Streaming ────────────────────────────────────────────────────────

// Build an empty assistant bubble with an empty content <span>.
// Returns the content span (the surface deltas append into).
function JW3ChatPanel.CreateStreamingBubble: TElement;
var
  Row:     TElement;
  Bubble:  TElement;
  Content: TElement;
  BubbleHandle, PaneHandle, TypingHandle: variant;
begin
  Row := TElement.Create('div', Self);
  Row.AddClass('jcp-row');
  Row.AddClass('jcp-row-asst');

  Bubble := TElement.Create('div', Row);
  Bubble.AddClass('jcp-bubble');
  Bubble.AddClass('jcp-bubble-asst');
  Bubble.AddClass('jcp-streaming');

  Content := TElement.Create('span', Bubble);

  // Initialise the raw-text accumulator on the bubble node.
  BubbleHandle := Bubble.Handle;
  asm (@BubbleHandle)._jcpText = ''; end;

  // Keep typing row beneath the latest message if visible.
  if FTypingRow <> nil then
  begin
    PaneHandle   := Handle;
    TypingHandle := FTypingRow.Handle;
    asm (@PaneHandle).appendChild(@TypingHandle); end;
  end;

  Result := Content;
end;

function JW3ChatPanel.BeginAssistant: TElement;
begin
  // Streaming visually replaces the dots, so hide them.
  HideTyping;
  Result := CreateStreamingBubble;
  ScrollToBottom;
end;

// Append a raw text delta. Plain text only during streaming - the
// final markdown pass happens in FinishAssistant. This:
//   - preserves any user selection inside earlier streamed text
//     (we append a text node rather than rewriting innerHTML)
//   - avoids re-parsing the entire response on every token
//   - keeps a `_jcpText` accumulator on the bubble for click-to-copy
procedure JW3ChatPanel.AppendAssistantChunk(ContentSpan: TElement;
                                            const Delta: String);
var
  SpanHandle: variant;
  Chunk: String;
begin
  if Delta = '' then exit;
  Chunk := Delta;
  SpanHandle := ContentSpan.Handle;
  asm
    var span   = @SpanHandle;
    var bubble = span.parentNode;
    span.appendChild(document.createTextNode(@Chunk));
    bubble._jcpText = (bubble._jcpText || '') + @Chunk;
  end;
  ScrollToBottom;
end;

// Re-render the full accumulated text through light markdown (so
// `**bold**` and newlines work), drop the streaming caret, attach
// the click-to-copy handler. Idempotent enough to call once per stream.
procedure JW3ChatPanel.FinishAssistant(ContentSpan: TElement);
var
  SpanHandle: variant;
  Full, Html_: String;
begin
  SpanHandle := ContentSpan.Handle;

  // Pull the accumulated raw text back into Pascal for FormatLightMd.
  Full := '';
  asm
    var span   = @SpanHandle;
    var bubble = span.parentNode;
    @Full = (bubble._jcpText || '');
  end;

  Html_ := FormatLightMd(Full);

  // Re-render the content span once with the full formatted HTML.
  asm (@SpanHandle).innerHTML = @Html_; end;

  // Wire the click handler and copy-hint inline against the bubble DOM
  // node. (Going via Pascal would require a TElement wrapper around
  // an existing node, which JElement does not expose at this layer.)
  asm
    var span    = @SpanHandle;
    var bubble  = span.parentNode;
    bubble.classList.remove('jcp-streaming');

    // Add the copied-label child if not already present.
    if (!bubble.querySelector('.jcp-copied')) {
      var hint = document.createElement('div');
      hint.className = 'jcp-copied';
      hint.textContent = 'copied';
      bubble.appendChild(hint);
    }

    // Click-to-copy reads _jcpText at click time.
    bubble.addEventListener('click', function(){
      var raw = bubble._jcpText || '';
      try { navigator.clipboard.writeText(raw); } catch(e) {}
      bubble.classList.add('jcp-copied-on');
      setTimeout(function(){
        bubble.classList.remove('jcp-copied-on');
      }, 900);
    });
  end;

  ScrollToBottom;
end;

// ── Public (whole-message, unchanged) ────────────────────────────────

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

procedure JW3ChatPanel.Reset;
var
  H: variant;
begin
  H := Handle;
  asm (@H).innerHTML = ''; end;   // drop every row, bubble and the typing node
  FTypingRow := nil;              // its DOM node is gone; force a rebuild next ShowTyping
end;

end.
