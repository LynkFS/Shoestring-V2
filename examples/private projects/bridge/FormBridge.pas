unit FormBridge;

// ═══════════════════════════════════════════════════════════════════════════
//
//  FormBridge — Bridge conversational interface
//
//  Single form: scrollable conversation panel above, input row below.
//  Dark text on warm light background, no chrome.
//
//  On load: restores the most recent active conversation from the API
//  and populates the panel so Nico sees where he left off.
//
//  Auth: acquires a JWT from /api/claude/auth/token on first use,
//  caches in sessionStorage. Re-acquires on 401.
//
//  State: conversation_id comes from the API (always real after first send).
//
//  Attachment: file/image picker stores data in window._bridgeAttach
//  (a plain JS object) to avoid Pascal field mangling in async callbacks.
//  window._bridgeFileInput holds the hidden <input type="file"> element.
//
//  To compile as standalone app, entrypoint:
//
//    uses Globals, FormBridge;
//    Application.CreateForm('Bridge', TFormBridge);
//    Application.GoToForm('Bridge');
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JForm, JElement, JPanel, JButton, JTextArea;

type
  TFormBridge = class(TW3Form)
  private
    FConvPanel:  JW3Panel;
    FAttachBar:  TElement;    // shown when a file is staged for send
    FInput:      JW3TextArea;
    FUploadBtn:  JW3Button;
    FBtn:        JW3Button;
    FToken:          String;
    FConvID:         String;    // empty until first send or history loaded
    FSending:        Boolean;
    FHistoryRetried: Boolean;  // prevents retry loop on persistent 403
    FLastUnread:     Integer;  // unread_notifications count from last status poll
    FLastNotifID:    Integer;  // highest notification id already shown

    procedure DoSend;
    procedure SendChat(const Msg: String);
    procedure AcquireToken(const Msg: String);
    procedure LoadHistory;
    procedure FetchMessages(const ConvID: String);
    procedure AppendBubble(const Role, Text: String);
    procedure StartPolling;
    procedure PollStatus;
    procedure FetchNewNotifications;

  protected
    procedure InitializeObject; override;
  end;

implementation

uses Globals;

const
  TOKEN_URL  = '/api/claude/auth/token';
  CHAT_URL   = '/api/claude/bridge/chat';
  CONV_URL   = '/api/claude/bridge/conversations';
  MSGS_URL   = '/api/claude/bridge/conversations/';
  STATUS_URL = '/api/claude/bridge/status';
  NOTIF_URL  = '/api/claude/bridge/notifications';

{ TFormBridge }

procedure TFormBridge.InitializeObject;
var InputRow: JW3Panel;
    stored:   String;
    barEl:    variant;
    Self_:    TFormBridge;
begin
  inherited;

  // ── Markdown bubble styles ────────────────────────────────────────────────
  AddStyleBlock(
    '.md-bubble p { margin: 0 0 0.6em 0; }' +
    '.md-bubble p:last-child { margin-bottom: 0; }' +
    '.md-bubble h1 { font-size: 1.2em; font-weight: 600; margin: 0.5em 0 0.3em; }' +
    '.md-bubble h2 { font-size: 1.1em; font-weight: 600; margin: 0.5em 0 0.3em; }' +
    '.md-bubble h3 { font-size: 1em; font-weight: 600; margin: 0.4em 0 0.2em; }' +
    '.md-bubble ul, .md-bubble ol { margin: 0.3em 0 0.6em 1.4em; padding: 0; }' +
    '.md-bubble li { margin-bottom: 0.2em; }' +
    '.md-bubble code { background: rgba(0,0,0,0.08); padding: 1px 5px; border-radius: 4px; font-size: 0.88em; font-family: ui-monospace, monospace; }' +
    '.md-bubble pre { background: #f3f3f0; border-radius: 6px; padding: 10px 12px; overflow-x: auto; margin: 0.5em 0; }' +
    '.md-bubble pre code { background: none; padding: 0; border-radius: 0; font-size: 0.85em; }' +
    '.md-bubble table { border-collapse: collapse; width: 100%; margin: 0.5em 0; font-size: 0.9em; }' +
    '.md-bubble th, .md-bubble td { border: 1px solid #ccc; padding: 5px 10px; text-align: left; }' +
    '.md-bubble th { background: rgba(0,0,0,0.06); font-weight: 600; }' +
    '.md-bubble blockquote { border-left: 3px solid #aaa; margin: 0.4em 0; padding: 0 0 0 10px; color: #666; }' +
    '.md-bubble hr { border: none; border-top: 1px solid #ccc; margin: 0.6em 0; }'
  );

  asm
    marked.setOptions({
      highlight: function(code, lang) {
        if (lang && hljs.getLanguage(lang)) {
          return hljs.highlight(code, { language: lang }).value;
        }
        return hljs.highlightAuto(code).value;
      }
    });
  end;

  // ── Page shell: warm off-white, full viewport, flex column ───────────────
  SetStyle('display',         'flex');
  SetStyle('flex-direction',  'column');
  SetStyle('height',          '100vh');
  SetStyle('background',      '#faf8f5');
  SetStyle('color',           '#2a2a2a');
  SetStyle('font-family',     'system-ui, -apple-system, sans-serif');
  SetStyle('font-size',       '15px');
  SetStyle('line-height',     '1.5');

  // ── Conversation panel ────────────────────────────────────────────────────
  FConvPanel := JW3Panel.Create(Self);
  FConvPanel.SetStyle('flex',           '1');
  FConvPanel.SetStyle('overflow-y',     'auto');
  FConvPanel.SetStyle('padding',        '28px 24px 12px');
  FConvPanel.SetStyle('display',        'flex');
  FConvPanel.SetStyle('flex-direction', 'column');
  FConvPanel.SetStyle('gap',            '14px');
  FConvPanel.SetStyle('user-select',    'text');

  // ── Attach bar (hidden until a file/image is staged) ─────────────────────
  // Sits between FConvPanel and InputRow in the flex column.
  // Contents are created via asm (img thumbnail + filename + ✕ button).
  FAttachBar := TElement.Create('div', Self);
  FAttachBar.SetStyle('display',      'none');
  FAttachBar.SetStyle('flex-direction','row');
  FAttachBar.SetStyle('align-items',  'center');
  FAttachBar.SetStyle('gap',          '10px');
  FAttachBar.SetStyle('padding',      '6px 24px');
  FAttachBar.SetStyle('background',   '#f0ede8');
  FAttachBar.SetStyle('border-top',   '1px solid #e8e4de');
  FAttachBar.SetStyle('flex-shrink',  '0');

  barEl := FAttachBar.Handle;

  asm
    // Build inner DOM for the attach bar
    var img   = document.createElement('img');
    img.style.cssText = 'width:44px;height:44px;object-fit:cover;border-radius:4px;flex-shrink:0;display:none';

    var name  = document.createElement('span');
    name.style.cssText = 'flex:1;font-size:13px;color:#555;overflow:hidden;text-overflow:ellipsis;white-space:nowrap';

    var close = document.createElement('span');
    close.textContent = 'x';
    close.style.cssText = 'cursor:pointer;color:#888;font-size:20px;padding:0 6px;line-height:1;flex-shrink:0';

    (@barEl).appendChild(img);
    (@barEl).appendChild(name);
    (@barEl).appendChild(close);

    // Store globally so file-reader callback and close handler can reach them
    window._bridgeAttachImg   = img;
    window._bridgeAttachName  = name;
    window._bridgeAttach      = null;

    // Close / cancel attachment
    close.addEventListener('click', function() {
      window._bridgeAttach = null;
      (@barEl).style.display = 'none';
    });

    // Hidden file input — accepted types: common images + text/pdf
    var fi = document.createElement('input');
    fi.type    = 'file';
    fi.accept  = 'image/jpeg,image/png,image/webp,.md,.txt,.pdf';
    fi.style.display = 'none';
    document.body.appendChild(fi);
    window._bridgeFileInput = fi;

    fi.addEventListener('change', function(e) {
      var file = e.target.files[0];
      if (!file) return;
      var reader = new FileReader();
      reader.onload = function(ev) {
        var dataURL   = ev.target.result;
        var comma     = dataURL.indexOf(',');
        var base64    = dataURL.slice(comma + 1);
        var mime      = dataURL.slice(5, comma).split(';')[0];
        window._bridgeAttach = { filename: file.name, media_type: mime, data: base64 };
        // Thumbnail for images; just the name for other types
        if (mime.startsWith('image/')) {
          window._bridgeAttachImg.src          = dataURL;
          window._bridgeAttachImg.style.display = 'inline-block';
        } else {
          window._bridgeAttachImg.style.display = 'none';
        }
        window._bridgeAttachName.textContent = file.name;
        (@barEl).style.display = 'flex';
      };
      reader.readAsDataURL(file);
      e.target.value = '';  // reset so the same file can be re-selected
    });
  end;

  // ── Input row ─────────────────────────────────────────────────────────────
  InputRow := JW3Panel.Create(Self);
  InputRow.SetStyle('display',        'flex');
  InputRow.SetStyle('flex-direction', 'row');
  InputRow.SetStyle('align-items',    'flex-end');
  InputRow.SetStyle('gap',            '10px');
  InputRow.SetStyle('padding',        '12px 24px 20px');
  InputRow.SetStyle('border-top',     '1px solid #e8e4de');
  InputRow.SetStyle('flex-shrink',    '0');

  // Upload / attach button — opens the hidden file picker
  FUploadBtn := JW3Button.Create(InputRow);
  FUploadBtn.Caption := '+';
  FUploadBtn.SetStyle('background',    'transparent');
  FUploadBtn.SetStyle('color',         '#555');
  FUploadBtn.SetStyle('border',        '1px solid #d4d0ca');
  FUploadBtn.SetStyle('border-radius', '6px');
  FUploadBtn.SetStyle('padding',       '0 12px');
  FUploadBtn.SetStyle('height',        '42px');
  FUploadBtn.SetStyle('font-size',     '18px');
  FUploadBtn.SetStyle('cursor',        'pointer');
  FUploadBtn.SetStyle('flex-shrink',   '0');
  FUploadBtn.OnClick := lambda
    asm window._bridgeFileInput.click(); end;
  end;

  FInput := JW3TextArea.Create(InputRow);
  FInput.SetStyle('flex',          '1');
  FInput.SetStyle('border',        '1px solid #d4d0ca');
  FInput.SetStyle('border-radius', '6px');
  FInput.SetStyle('padding',       '10px 14px');
  FInput.SetStyle('font-size',     '15px');
  FInput.SetStyle('background',    '#ffffff');
  FInput.SetStyle('color',         '#2a2a2a');
  FInput.SetStyle('resize',        'none');
  FInput.Rows        := 3;
  FInput.Placeholder := 'Message Bridge';

  // Auto-expand up to 8 rows (~200px) as content grows
  FInput.Handle.addEventListener('input', procedure(E: variant)
  begin
    asm
      var el = (@E).target;
      el.style.height = 'auto';
      el.style.height = Math.min(el.scrollHeight, 200) + 'px';
    end;
  end);

  // Enter sends; Shift+Enter inserts newline (default textarea behaviour)
  FInput.Handle.addEventListener('keydown', procedure(E: variant)
  begin
    if (String(E.key) = 'Enter') and not Boolean(E.shiftKey) then
    begin
      asm (@E).preventDefault(); end;
      if not FSending then DoSend;
    end;
  end);

  FBtn := JW3Button.Create(InputRow);
  FBtn.Caption := 'Send';
  FBtn.SetStyle('background',    '#2a2a2a');
  FBtn.SetStyle('color',         '#f5f3f0');
  FBtn.SetStyle('border',        'none');
  FBtn.SetStyle('border-radius', '6px');
  FBtn.SetStyle('padding',       '0 20px');
  FBtn.SetStyle('height',        '42px');
  FBtn.SetStyle('font-size',     '15px');
  FBtn.SetStyle('cursor',        'pointer');
  FBtn.SetStyle('flex-shrink',   '0');
  FBtn.OnClick := lambda
    if not FSending then DoSend;
  end;

  // State
  FConvID      := '';
  FSending     := false;
  FLastUnread  := 0;
  FLastNotifID := 0;

  // Restore cached token, then load most recent conversation
  asm @stored = sessionStorage.getItem('bridge_token') || ''; end;
  FToken := stored;
  LoadHistory;
  StartPolling;
end;

// ── Load recent conversation on startup ───────────────────────────────────

procedure TFormBridge.LoadHistory;
var xhr:   variant;
    Self_: TFormBridge;
begin
  // If no token yet, acquire one silently then call LoadHistory again
  if FToken = '' then
  begin
    Self_ := Self;
    asm @xhr = new XMLHttpRequest(); end;
    xhr.open('POST', TOKEN_URL);
    xhr.setRequestHeader('Content-Type', 'application/json');

    xhr.onreadystatechange := procedure()
    begin
      if xhr.readyState <> 4 then exit;
      if (xhr.status >= 200) and (xhr.status < 300) then
      begin
        var data: variant;
        asm @data = JSON.parse((@xhr).responseText); end;
        Self_.FToken := String(data.token);
        asm sessionStorage.setItem('bridge_token', (@Self_).FToken); end;
        Self_.LoadHistory;
      end;
      // Silently skip if token acquisition fails on load — user can still chat
    end;

    xhr.send('{}');
    exit;
  end;

  // Fetch recent conversations
  Self_ := Self;
  asm @xhr = new XMLHttpRequest(); end;
  xhr.open('GET', CONV_URL);
  xhr.setRequestHeader('Authorization', 'Bearer ' + FToken);

  xhr.onreadystatechange := procedure()
  begin
    if xhr.readyState <> 4 then exit;

    if (xhr.status >= 200) and (xhr.status < 300) then
    begin
      var data: variant;
      asm @data = JSON.parse((@xhr).responseText); end;
      var count: Integer;
      asm @count = (@data).conversations ? (@data).conversations.length : 0; end;
      if count > 0 then
      begin
        var cid: String;
        asm @cid = String((@data).conversations[0].id); end;
        Self_.FConvID := cid;
        Self_.FetchMessages(cid);
      end;
    end
    else if (xhr.status = 401) or (xhr.status = 403) then
    begin
      // Stale or invalid token — clear and retry once with a fresh token
      if not Self_.FHistoryRetried then
      begin
        Self_.FHistoryRetried := true;
        Self_.FToken := '';
        asm sessionStorage.removeItem('bridge_token'); end;
        Self_.LoadHistory;
      end;
      // Second 403 means a real server auth problem — give up silently
    end;
  end;

  xhr.send(null);
end;

procedure TFormBridge.FetchMessages(const ConvID: String);
var xhr:   variant;
    Self_: TFormBridge;
begin
  Self_ := Self;
  asm @xhr = new XMLHttpRequest(); end;
  xhr.open('GET', MSGS_URL + ConvID + '/messages?limit=50');
  xhr.setRequestHeader('Authorization', 'Bearer ' + FToken);

  xhr.onreadystatechange := procedure()
  begin
    if xhr.readyState <> 4 then exit;

    if (xhr.status >= 200) and (xhr.status < 300) then
    begin
      var data: variant;
      asm @data = JSON.parse((@xhr).responseText); end;
      var count: Integer;
      asm @count = (@data).messages ? (@data).messages.length : 0; end;

      if count > 0 then
      begin
        // Separator so Nico knows this is prior history
        var Sep := TElement.Create('div', Self_.FConvPanel);
        Sep.SetStyle('align-self', 'center');
        Sep.SetStyle('color',      '#c0bbb4');
        Sep.SetStyle('font-size',  '12px');
        Sep.SetStyle('padding',    '2px 0 6px');
        Sep.SetText('-- earlier --');

        var i: Integer;
        for i := 0 to count - 1 do
        begin
          var role, content: String;
          asm
            @role    = String((@data).messages[@i].role);
            @content = String((@data).messages[@i].content);
          end;
          Self_.AppendBubble(role, content);
        end;
      end;
    end
    else if (xhr.status = 401) or (xhr.status = 403) then
    begin
      Self_.FToken := '';
      asm sessionStorage.removeItem('bridge_token'); end;
    end;
  end;

  xhr.send(null);
end;

// ── Send initiation ────────────────────────────────────────────────────────

procedure TFormBridge.DoSend;
var Msg:        String;
    MsgLow:     String;
    InputEl:    variant;
    HasAttach:  Boolean;
    AttachName: String;
    DispMsg:    String;
begin
  Msg := FInput.Value.Trim;

  // Check attachment state (stored in JS global to survive async FileReader)
  asm
    var att    = window._bridgeAttach;
    @HasAttach = !!att;
    @AttachName = att ? att.filename : '';
  end;

  if (Msg = '') and not HasAttach then exit;

  // Client-side commands — handled locally, no API call
  MsgLow := LowerCase(Msg);
  if (MsgLow = 'clear') or (MsgLow = 'clear screen') or (MsgLow = 'new chat') then
  begin
    FInput.Value := '';
    InputEl := FInput.Handle;
    asm (@InputEl).style.height = ''; end;
    asm window._bridgeAttach = null; end;
    FAttachBar.SetStyle('display', 'none');
    FConvPanel.Clear;
    FConvID := '';
    AppendBubble('system', 'New conversation started.');
    exit;
  end;

  // Build display text for the user bubble
  DispMsg := Msg;
  if HasAttach then
  begin
    if DispMsg <> '' then
      DispMsg := DispMsg + #10 + '[' + AttachName + ']'
    else
      DispMsg := '[' + AttachName + ']';
  end;

  FInput.Value := '';
  InputEl := FInput.Handle;
  asm (@InputEl).style.height = ''; end;   // shrink back to 3-row default

  // Hide the attach bar immediately (data stays in window._bridgeAttach until SendChat captures it)
  if HasAttach then
    FAttachBar.SetStyle('display', 'none');

  AppendBubble('user', DispMsg);
  FSending := true;
  FBtn.SetStyle('opacity', '0.45');
  FBtn.SetStyle('pointer-events', 'none');

  if FToken = '' then
    AcquireToken(Msg)
  else
    SendChat(Msg);
end;

// ── Token acquisition (for send flow) ─────────────────────────────────────

procedure TFormBridge.AcquireToken(const Msg: String);
var xhr:   variant;
    Self_: TFormBridge;
begin
  Self_ := Self;
  asm @xhr = new XMLHttpRequest(); end;
  xhr.open('POST', TOKEN_URL);
  xhr.setRequestHeader('Content-Type', 'application/json');

  xhr.onreadystatechange := procedure()
  begin
    if xhr.readyState <> 4 then exit;

    if (xhr.status >= 200) and (xhr.status < 300) then
    begin
      var data: variant;
      asm @data = JSON.parse((@xhr).responseText); end;
      Self_.FToken := String(data.token);
      asm sessionStorage.setItem('bridge_token', (@Self_).FToken); end;
      Self_.SendChat(Msg);
    end
    else
    begin
      Self_.AppendBubble('error', 'Connection failed (' + IntToStr(xhr.status) + ')');
      Self_.FSending := false;
      Self_.FBtn.SetStyle('opacity', '1');
      Self_.FBtn.SetStyle('pointer-events', '');
    end;
  end;

  xhr.send('{}');
end;

// ── API call ───────────────────────────────────────────────────────────────

procedure TFormBridge.SendChat(const Msg: String);
var Token:    String;
    ChatURL:  String;
    Self_:    TFormBridge;
    Bubble:   TElement;
    BubbleEl: variant;
    PanelEl:  variant;
    Body:     String;
begin
  Token   := FToken;
  ChatURL := CHAT_URL;
  Self_   := Self;

  asm
    var convID  = (@Self_).FConvID;
    var att     = window._bridgeAttach;
    var payload = {
      message:         @Msg,
      conversation_id: convID !== '' ? parseInt(convID, 10) : null,
      channel:         'web',
      stream:          true
    };
    if (att) {
      payload.images = [{ filename: att.filename, media_type: att.media_type, data: att.data }];
    }
    window._bridgeAttach  = null;
    window._bridgeLastMsg = @Msg;
    @Body = JSON.stringify(payload);
  end;

  // Create the assistant bubble immediately — the stream will fill it
  Bubble := TElement.Create('div', FConvPanel);
  Bubble.SetStyle('align-self',    'flex-start');
  Bubble.SetStyle('background',    '#edebe7');
  Bubble.SetStyle('color',         '#2a2a2a');
  Bubble.SetStyle('padding',       '10px 14px');
  Bubble.SetStyle('border-radius', '14px 14px 14px 3px');
  Bubble.SetStyle('max-width',     '82%');
  Bubble.SetStyle('line-height',   '1.6');
  Bubble.AddClass('md-bubble');

  BubbleEl := Bubble.Handle;
  PanelEl  := FConvPanel.Handle;

  asm
    var bubbleEl = @BubbleEl;
    var panelEl  = @PanelEl;
    var token    = @Token;
    var chatUrl  = @ChatURL;
    var body     = @Body;

    var accumulated    = '';
    var renderTimer    = null;
    var deltaCount     = 0;
    var lastRenderTime = 0;

    function renderMarkdown() {
      if (renderTimer !== null) { clearTimeout(renderTimer); renderTimer = null; }
      deltaCount     = 0;
      lastRenderTime = Date.now();
      var html = DOMPurify.sanitize(marked.parse(accumulated));
      bubbleEl.innerHTML = html;
      bubbleEl.querySelectorAll('pre code').forEach(function(b) { hljs.highlightElement(b); });
      panelEl.scrollTop = panelEl.scrollHeight;
    }

    function onDelta() {
      deltaCount++;
      if (deltaCount >= 50 || (Date.now() - lastRenderTime) >= 300) {
        renderMarkdown();
      } else if (renderTimer === null) {
        renderTimer = setTimeout(renderMarkdown, 300);
      }
    }

    function dispatch(name, detail) {
      panelEl.dispatchEvent(new CustomEvent(name, { detail: detail || {} }));
    }

    fetch(chatUrl, {
      method:  'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token },
      body:    body
    }).then(function(response) {
      if (response.status === 401) {
        dispatch('bridge-stream-401');
        return;
      }
      if (!response.ok || !response.body) {
        bubbleEl.textContent = 'Error ' + response.status;
        bubbleEl.style.color = '#cc0000';
        dispatch('bridge-stream-error');
        return;
      }

      var reader  = response.body.getReader();
      var decoder = new TextDecoder();
      var buffer  = '';

      function pump(result) {
        if (result.done) return;
        buffer += decoder.decode(result.value, { stream: true });
        var lines = buffer.split('\n');
        buffer = lines.pop();

        for (var i = 0; i < lines.length; i++) {
          var line = lines[i];
          if (!line.startsWith('data: ')) continue;
          try {
            var evt = JSON.parse(line.slice(6));
            if (evt.type === 'status') {
              if (accumulated === '') {
                bubbleEl.innerHTML = '<em style="color:#999;font-style:italic">' + evt.text + '</em>';
                panelEl.scrollTop = panelEl.scrollHeight;
              }
            } else if (evt.type === 'delta') {
              accumulated += evt.text;
              onDelta();
            } else if (evt.type === 'done') {
              if (renderTimer !== null) { clearTimeout(renderTimer); renderTimer = null; }
              if (accumulated) { renderMarkdown(); } else { bubbleEl.innerHTML = ''; }
              dispatch('bridge-stream-done', { conversation_id: evt.conversation_id });
            } else if (evt.type === 'error') {
              bubbleEl.textContent = evt.text;
              bubbleEl.style.color = '#cc0000';
              dispatch('bridge-stream-error');
            }
          } catch(e) {}
        }
        return reader.read().then(pump);
      }

      return reader.read().then(pump);
    }).catch(function(err) {
      bubbleEl.textContent = 'Connection error';
      bubbleEl.style.color = '#cc0000';
      dispatch('bridge-stream-error');
    });
  end;
end;

// ── Bubble rendering ───────────────────────────────────────────────────────

procedure TFormBridge.AppendBubble(const Role, Text: String);
var Bubble:  TElement;
    PanelEl: variant;
begin
  Bubble := TElement.Create('div', FConvPanel);

  if Role = 'user' then
  begin
    Bubble.SetStyle('align-self',    'flex-end');
    Bubble.SetStyle('background',    '#2a2a2a');
    Bubble.SetStyle('color',         '#f5f3f0');
    Bubble.SetStyle('padding',       '10px 14px');
    Bubble.SetStyle('border-radius', '14px 14px 3px 14px');
    Bubble.SetStyle('max-width',     '72%');
    Bubble.SetStyle('line-height',   '1.55');
  end
  else if Role = 'assistant' then
  begin
    Bubble.SetStyle('align-self',    'flex-start');
    Bubble.SetStyle('background',    '#edebe7');
    Bubble.SetStyle('color',         '#2a2a2a');
    Bubble.SetStyle('padding',       '10px 14px');
    Bubble.SetStyle('border-radius', '14px 14px 14px 3px');
    Bubble.SetStyle('max-width',     '82%');
    Bubble.SetStyle('line-height',   '1.6');
    Bubble.AddClass('md-bubble');
  end
  else if Role = 'notification' then
  begin
    Bubble.SetStyle('align-self',    'flex-start');
    Bubble.SetStyle('background',    '#fef9ec');
    Bubble.SetStyle('color',         '#5c4a1e');
    Bubble.SetStyle('border-left',   '3px solid #c4992a');
    Bubble.SetStyle('padding',       '7px 12px');
    Bubble.SetStyle('border-radius', '0 8px 8px 0');
    Bubble.SetStyle('max-width',     '80%');
    Bubble.SetStyle('font-size',     '13px');
    Bubble.SetStyle('line-height',   '1.5');
  end
  else  // error / system
  begin
    Bubble.SetStyle('align-self',  'center');
    Bubble.SetStyle('color',       '#aaa');
    Bubble.SetStyle('font-size',   '13px');
  end;

  if Role = 'assistant' then
  begin
    var BubbleEl: variant;
    BubbleEl := Bubble.Handle;
    asm
      var raw = String(@Text);
      var html = DOMPurify.sanitize(marked.parse(raw));
      (@BubbleEl).innerHTML = html;
      (@BubbleEl).querySelectorAll('pre code').forEach(function(block) {
        hljs.highlightElement(block);
      });
    end;
  end
  else
    Bubble.SetText(Text);

  // Handle is a static method — capture via Pascal assignment before asm block
  PanelEl := FConvPanel.Handle;
  asm
    (@PanelEl).scrollTop = (@PanelEl).scrollHeight;
  end;
end;

// ── Notification polling ───────────────────────────────────────────────────
//
//  setInterval cannot invoke a Pascal method directly (name mangling).
//  Workaround: attach a procedure(E:variant) listener to a custom DOM event
//  on FConvPanel, then fire that event from setInterval in an asm block.

procedure TFormBridge.StartPolling;
var PanelEl: variant;
    Self_:   TFormBridge;
begin
  Self_   := Self;
  PanelEl := FConvPanel.Handle;

  FConvPanel.Handle.addEventListener('bridge-status-poll', procedure(E: variant)
  begin
    Self_.PollStatus;
  end);

  FConvPanel.Handle.addEventListener('bridge-stream-done', procedure(E: variant)
  begin
    var cid: String;
    asm
      var d = (@E).detail;
      @cid = (d && d.conversation_id) ? String(d.conversation_id) : '';
    end;
    if cid <> '' then Self_.FConvID := cid;
    Self_.FSending := false;
    Self_.FBtn.SetStyle('opacity', '1');
    Self_.FBtn.SetStyle('pointer-events', '');
  end);

  FConvPanel.Handle.addEventListener('bridge-stream-error', procedure(E: variant)
  begin
    Self_.FSending := false;
    Self_.FBtn.SetStyle('opacity', '1');
    Self_.FBtn.SetStyle('pointer-events', '');
  end);

  FConvPanel.Handle.addEventListener('bridge-stream-401', procedure(E: variant)
  begin
    Self_.FToken := '';
    asm sessionStorage.removeItem('bridge_token'); end;
    var lastMsg: String;
    asm @lastMsg = window._bridgeLastMsg || ''; end;
    Self_.AcquireToken(lastMsg);
  end);

  asm
    setInterval(function() {
      (@PanelEl).dispatchEvent(new CustomEvent('bridge-status-poll'));
    }, 30000);
  end;
end;

procedure TFormBridge.PollStatus;
var xhr:   variant;
    Self_: TFormBridge;
begin
  if FToken = '' then exit;

  Self_ := Self;
  asm @xhr = new XMLHttpRequest(); end;
  xhr.open('GET', STATUS_URL);
  xhr.setRequestHeader('Authorization', 'Bearer ' + FToken);

  xhr.onreadystatechange := procedure()
  begin
    if xhr.readyState <> 4 then exit;

    if (xhr.status >= 200) and (xhr.status < 300) then
    begin
      var data: variant;
      asm @data = JSON.parse((@xhr).responseText); end;
      var count: Integer;
      asm @count = parseInt((@data).unread_notifications, 10) || 0; end;
      if count > Self_.FLastUnread then
        Self_.FetchNewNotifications;
      Self_.FLastUnread := count;
    end
    else if (xhr.status = 401) or (xhr.status = 403) then
    begin
      Self_.FToken := '';
      asm sessionStorage.removeItem('bridge_token'); end;
    end;
  end;

  xhr.send(null);
end;

procedure TFormBridge.FetchNewNotifications;
var xhr:   variant;
    Self_: TFormBridge;
begin
  Self_ := Self;
  asm @xhr = new XMLHttpRequest(); end;
  xhr.open('GET', NOTIF_URL + '?unread=true');
  xhr.setRequestHeader('Authorization', 'Bearer ' + FToken);

  xhr.onreadystatechange := procedure()
  begin
    if xhr.readyState <> 4 then exit;
    if not ((xhr.status >= 200) and (xhr.status < 300)) then exit;

    var data: variant;
    asm @data = JSON.parse((@xhr).responseText); end;
    var count: Integer;
    asm @count = (@data).notifications ? (@data).notifications.length : 0; end;
    if count = 0 then exit;

    var maxId: Integer;
    maxId := Self_.FLastNotifID;

    // API returns newest-first — iterate in reverse for chronological display
    var i: Integer;
    for i := count - 1 downto 0 do
    begin
      var nid: Integer;
      var msg, sev: String;
      asm
        @nid = parseInt((@data).notifications[@i].id, 10) || 0;
        @msg = String((@data).notifications[@i].message);
        @sev = String((@data).notifications[@i].severity);
      end;
      if nid > Self_.FLastNotifID then
      begin
        Self_.AppendBubble('notification', '[' + sev + '] ' + msg);
        if nid > maxId then maxId := nid;
      end;
    end;

    Self_.FLastNotifID := maxId;
  end;

  xhr.send(null);
end;

end.
