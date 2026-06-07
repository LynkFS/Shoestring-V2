unit JLLMStore;

// ═══════════════════════════════════════════════════════════════════════════
//
//  JLLMStore — bridge a streaming turn into a JW3DataStore
//
//  Optional convenience. Decouples the stream transport from the UI exactly
//  the way the booklet's DataStore chapter prescribes: the producer (this
//  bridge) never knows who renders; the chat panel just Subscribes to keys.
//
//  Keys written under <ABase>:
//    <ABase>.delta    cumulative assistant text (grows per token)
//    <ABase>.status   'streaming' | 'done' | 'error'
//    <ABase>.error    error message (only on failure)
//
//  Multi-turn is still owned by the adapter; this only mirrors one turn's
//  progress into observable state.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JLLMTypes, JLLMAdapter, JDataStore;

procedure StreamIntoStore(AAdapter: TLLMAdapter; AStore: JW3DataStore;
                          const ABase, AUserText: String);

implementation

procedure StreamIntoStore(AAdapter: TLLMAdapter; AStore: JW3DataStore;
                          const ABase, AUserText: String);
var
  acc: String;
begin
  acc := '';
  AStore.Put(ABase + '.error',  '');
  AStore.Put(ABase + '.delta',  '');
  AStore.Put(ABase + '.status', 'streaming');

  AAdapter.SendStreaming(AUserText,
    procedure(const Chunk: String)
    begin
      acc := acc + Chunk;
      AStore.Put(ABase + '.delta', acc);
    end,
    procedure(const AResult: TLLMResult)
    begin
      // Use the assembled text from the result (authoritative).
      AStore.Put(ABase + '.delta',  AResult.Text);
      AStore.Put(ABase + '.status', 'done');
    end,
    procedure(AStatus: Integer; const AMsg: String)
    begin
      AStore.Put(ABase + '.error',  AMsg);
      AStore.Put(ABase + '.status', 'error');
    end);
end;

end.
