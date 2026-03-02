unit NodeHttpServer;

// ═══════════════════════════════════════════════════════════════════════════
//
//  NodeHttpServer
//
//  HTTP server using Node's built-in http module. Zero dependencies.
//  Compiles to JavaScript that runs under: node index.js
//
//  Starts on port 3000 (or PORT env variable). Four routes:
//
//    GET /        → welcome JSON
//    GET /time    → server time (UTC, ISO, epoch)
//    GET /info    → OS and process info
//    GET /echo    → echoes query parameters back
//    *            → 404
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses NodeTypes;

procedure StartServer;

implementation

procedure StartServer;
var
  http, os, url: variant;
  server: variant;
  port: variant;
begin
  http := ReqNodeModule('http');
  os   := ReqNodeModule('os');
  url  := ReqNodeModule('url');

  server := http.createServer(
    procedure(req, res: variant)
    var
      parsed, query: variant;
      pathname: String;
      body: String;
      code: Integer;
    begin
      parsed   := url.parse(String(req.url), true);
      pathname := String(parsed.pathname);
      query    := parsed.query;

      code := 200;

      if pathname = '/' then
      begin
        var a: variant := new JObject;
        a.service := 'Shoestring Node.js';
        a.status :=  'running';
        a.message := 'Hello from Object Pascal on Node';
        body := JSON.Stringify(a);
      end

//        asm
//          @body = JSON.stringify({
//            service: 'Shoestring Node.js',
//            status:  'running',
//            message: 'Hello from Object Pascal on Node'
//          });
//        end;

      else if pathname = '/time' then
      begin
        asm
          @body = JSON.stringify({
            utc:   new Date().toUTCString(),
            iso:   new Date().toISOString(),
            epoch: Date.now()
          });
        end;
      end

      else if pathname = '/info' then
      begin
        asm
          @body = JSON.stringify({
            platform: (@os).platform(),
            arch:     (@os).arch(),
            hostname: (@os).hostname(),
            cpus:     (@os).cpus().length,
            totalMem: Math.round((@os).totalmem() / 1048576) + ' MB',
            freeMem:  Math.round((@os).freemem() / 1048576) + ' MB',
            uptime:   Math.round((@os).uptime()) + 's',
            node:     process.version
          });
        end;
      end

      else if pathname = '/echo' then
      begin
        asm @body = JSON.stringify({ echo: @query }); end;
      end

      else
      begin
        code := 404;
        asm
          @body = JSON.stringify({
            error: 'Not found',
            path:  @pathname
          });
        end;
      end;

      // Send response
      asm
        res.writeHead(@code, {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        });
      end;
      res.end(body);

      // Log
      console.log(String(req.method) + ' ' + pathname
        + ' -> ' + IntToStr(code));
    end
  );

  // Port from environment or default 3000
  asm @port = process.env.PORT || 3000; end;

  server.listen(port, procedure()
  begin
    console.log('');
    console.log('Shoestring HTTP server listening on port ' + String(port));
    console.log('');
    console.log('  GET /       welcome');
    console.log('  GET /time   server time');
    console.log('  GET /info   OS and process info');
    console.log('  GET /echo   echo query params');
    console.log('');
  end);
end;

initialization
  StartServer;
end.
