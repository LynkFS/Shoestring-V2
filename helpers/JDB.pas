unit JDB;

// ═══════════════════════════════════════════════════════════════════════════
//
//  JDB — Database Query Helper
//
//  Thin wrapper around PostForm for PHP-backed MySQL endpoints.
//  Handles the ok/error check so form code never has to.
//
//  Usage — standalone procedure (one-off query):
//
//    DBQuery(ApiURL, 'action=books_all',
//      procedure(Data: variant)
//      begin
//        // Data.ok is guaranteed true here
//        asm (@FList).Handle.innerHTML = buildRows(@Data); end;
//      end,
//      procedure(Msg: String)
//      begin
//        Toast(Msg, ttDanger, 4000);
//      end
//    );
//
//  Usage — TDBClient class (multiple queries to the same endpoint):
//
//    // In the form's private section:
//    FDB: TDBClient;
//
//    // In InitializeObject:
//    FDB := TDBClient.Create('https://lynkfs.com/db-connect/raw_api_native.php');
//
//    // Querying:
//    FDB.Query('sql_statement=SELECT * FROM books',
//      procedure(Data: variant) begin ... end,
//      procedure(Msg: String) begin Toast(Msg, ttDanger, 4000); end
//    );
//
//  DBEncode — URL-encodes a string for use in the POST body:
//
//    var body := 'action=books_insert' +
//      '&title='  + DBEncode(FTitleIn.Value) +
//      '&author=' + DBEncode(FAuthorIn.Value);
//    FDB.Query(body, OnSuccess, OnError);
//
//  Response contract:
//
//    The PHP endpoint must return JSON with an "ok" boolean field.
//    On ok=true  → OnSuccess fires with the full Data variant.
//    On ok=false → OnError fires with Data.error string.
//    On HTTP/network error → OnError fires with the status message.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses HttpClient;

type
  TDBSuccessCallback = procedure(Data: variant);
  TDBErrorCallback   = procedure(Msg: String);

  TDBClient = class
  private
    FURL: String;
  public
    constructor Create(const URL: String);
    destructor  Destroy; override;

    procedure Query(const Body: String;
      OnSuccess: TDBSuccessCallback; OnError: TDBErrorCallback);

    property URL: String read FURL write FURL;
  end;

procedure DBQuery(const URL, Body: String;
  OnSuccess: TDBSuccessCallback; OnError: TDBErrorCallback);

function DBEncode(const S: String): String;

implementation


// ── DBEncode ─────────────────────────────────────────────────────────────────

function DBEncode(const S: String): String;
begin
  asm @Result = encodeURIComponent(@S); end;
end;


// ── DBQuery ───────────────────────────────────────────────────────────────────

procedure DBQuery(const URL, Body: String;
  OnSuccess: TDBSuccessCallback; OnError: TDBErrorCallback);
begin
  PostForm(URL, Body,
    procedure(Data: variant)
    var errMsg: String;
    begin
      if Data.ok then
        OnSuccess(Data)
      else
      begin
        asm @errMsg = (@Data).error || 'Unknown error'; end;
        OnError(errMsg);
      end;
    end,
    procedure(Status: Integer; Msg: String)
    begin
      OnError(Msg);
    end
  );
end;


// ── TDBClient ─────────────────────────────────────────────────────────────────

constructor TDBClient.Create(const URL: String);
begin
  inherited Create;
  FURL := URL;
end;

destructor TDBClient.Destroy;
begin
  inherited;
end;

procedure TDBClient.Query(const Body: String;
  OnSuccess: TDBSuccessCallback; OnError: TDBErrorCallback);
begin
  DBQuery(FURL, Body, OnSuccess, OnError);
end;

end.
