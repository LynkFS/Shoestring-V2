unit FormChatStreamTest;

// Manual test of JW3ChatPanel streaming. No LLM, no network -
// uses setTimeout to simulate token-by-token arrival.
//
// Register in app.entrypoint.pas:
//     uses ..., FormChatStreamTest;
//     Application.CreateForm('FormChatStream', TFormChatStream);

interface

uses JElement, JForm, JButton, JChatPanel;

type
  TFormChatStream = class(TW3Form)
  private
    FChat: JW3ChatPanel;
    FBtn:  JW3Button;
    FSpan: TElement;
    procedure RunDemo;
    procedure StepShowTyping;
    procedure StepBegin;
    procedure StepChunk1;
    procedure StepChunk2;
    procedure StepChunk3;
    procedure StepChunk4;
    procedure StepFinish;
  public
    procedure InitializeObject; override;
  end;

implementation

uses Globals;

procedure TFormChatStream.InitializeObject;
begin
  inherited;

  FChat := JW3ChatPanel.Create(Self);
  FChat.SetStyle('height', '420px');
  FChat.SetStyle('margin', '12px');

  FBtn := JW3Button.Create(Self);
  FBtn.Caption := 'Run streaming demo';
  FBtn.SetStyle('margin', '12px');
  // TNotifyEvent, no params -> lambda per CLAUDE.md
  FBtn.OnClick := procedure (Sender: TObject) 
  begin 
    RunDemo; 
  end;
end;

// Helper: schedule a Pascal method via setTimeout.
// `Method` is captured by name in the JS closure.
procedure ScheduleStep(Ms: Integer; Method: variant);
begin
  asm setTimeout(@Method, @Ms); end;
end;

procedure TFormChatStream.RunDemo;
var
  M: variant;
begin
  FChat.AppendUser('Tell me a poem about Brisbane.');

  // Wrap each step as a JS-callable closure via variant.
  // Pascal -> variant conversion of a method gives a bound callable.

  M := @StepShowTyping;  asm setTimeout(@M,  400); end;
  M := @StepBegin;       asm setTimeout(@M, 1000); end;
  M := @StepChunk1;      asm setTimeout(@M, 1250); end;
  M := @StepChunk2;      asm setTimeout(@M, 1500); end;
  M := @StepChunk3;      asm setTimeout(@M, 1750); end;
  M := @StepChunk4;      asm setTimeout(@M, 2000); end;
  M := @StepFinish;      asm setTimeout(@M, 2300); end;
end;

procedure TFormChatStream.StepShowTyping;
begin
  FChat.ShowTyping;
end;

procedure TFormChatStream.StepBegin;
begin
  FSpan := FChat.BeginAssistant;
end;

procedure TFormChatStream.StepChunk1;
begin
  FChat.AppendAssistantChunk(FSpan, 'Beneath a sky of ');
end;

procedure TFormChatStream.StepChunk2;
begin
  FChat.AppendAssistantChunk(FSpan, 'subtropical blue, ');
end;

procedure TFormChatStream.StepChunk3;
begin
  FChat.AppendAssistantChunk(FSpan, 'the river bends through **Brisbane**');
end;

procedure TFormChatStream.StepChunk4;
begin
  FChat.AppendAssistantChunk(FSpan, ',' + #10 + 'slow and brown.');
end;

procedure TFormChatStream.StepFinish;
begin
  FChat.FinishAssistant(FSpan);
end;

end.
