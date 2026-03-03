unit HttpClient;

// ═══════════════════════════════════════════════════════════════════════════
//
//  HTTP Client
//
//  Standalone procedures wrapping XMLHttpRequest. No class to create,
//  no object to manage. Call the procedure, get a callback.
//
//  Usage:
//
//    FetchJSON('https://api.example.com/users',
//      procedure(Data: variant)
//      begin
//        var name := Data.name;
//      end,
//      procedure(Status: Integer; Msg: String)
//      begin
//        Toast('Failed: ' + Msg, ttDanger);
//      end
//    );
//
//    PostJSON('https://api.example.com/users',
//      '{"name":"Nico","email":"nico@example.com"}',
//      procedure(Data: variant) begin end,
//      procedure(Status: Integer; Msg: String) begin end
//    );
//
//    FetchText('https://example.com/readme.txt',
//      procedure(Text: String) begin end,
//      procedure(Status: Integer; Msg: String) begin end
//    );
//
//  All three are async. The callbacks fire when the request completes.
//  The XHR object is created and discarded — JavaScript GC handles it.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

type
  TJSONCallback    = procedure(Data: variant);
  TTextCallback    = procedure(Text: String);
  TErrorCallback   = procedure(Status: Integer; Message: String);

procedure FetchJSON(const URL: String;
  OnSuccess: TJSONCallback; OnError: TErrorCallback);

procedure FetchText(const URL: String;
  OnSuccess: TTextCallback; OnError: TErrorCallback);

procedure PostJSON(const URL, Body: String;
  OnSuccess: TJSONCallback; OnError: TErrorCallback);

procedure HttpRequest(const Method, URL: String;
  const Body: String; const ContentType: String;
  OnSuccess: TJSONCallback; OnTextSuccess: TTextCallback;
  OnError: TErrorCallback; ParseJSON: Boolean);

implementation

uses Globals;


//=============================================================================
// Core request — all public procedures delegate here
//=============================================================================

procedure HttpRequest(const Method, URL: String;
  const Body: String; const ContentType: String;
  OnSuccess: TJSONCallback; OnTextSuccess: TTextCallback;
  OnError: TErrorCallback; ParseJSON: Boolean);
var
  xhr: variant;
begin
  asm @xhr = new XMLHttpRequest(); end;

  xhr.open(Method, URL);

  if ContentType <> '' then
    xhr.setRequestHeader('Content-Type', ContentType);

  xhr.onreadystatechange := procedure()
  begin
    if xhr.readyState <> 4 then exit;

    if (xhr.status >= 200) and (xhr.status < 300) then
    begin
      if ParseJSON then
      begin
        var data: variant;
        try
          asm @data = JSON.parse((@xhr).responseText); end;
        except
          if assigned(OnError) then
            OnError(xhr.status, 'JSON parse error');
          exit;
        end;
        if assigned(OnSuccess) then
          OnSuccess(data);
      end
      else
      begin
        if assigned(OnTextSuccess) then
          OnTextSuccess(xhr.responseText);
      end;
    end
    else
    begin
      if assigned(OnError) then
      begin
        var Msg := String(xhr.statusText);
        if Msg = '' then Msg := 'Network error';
        OnError(xhr.status, Msg);
      end;
    end;
  end;

  if Body <> '' then
    xhr.send(Body)
  else
    xhr.send(null);
end;


//=============================================================================
// Public API
//=============================================================================

procedure FetchJSON(const URL: String;
  OnSuccess: TJSONCallback; OnError: TErrorCallback);
begin
  HttpRequest('GET', URL, '', '', OnSuccess, nil, OnError, true);
end;

procedure FetchText(const URL: String;
  OnSuccess: TTextCallback; OnError: TErrorCallback);
begin
  HttpRequest('GET', URL, '', '', nil, OnSuccess, OnError, false);
end;

procedure PostJSON(const URL, Body: String;
  OnSuccess: TJSONCallback; OnError: TErrorCallback);
begin
  HttpRequest('POST', URL, Body, 'application/json',
    OnSuccess, nil, OnError, true);
end;

end.
