unit NodeHello;

// ═══════════════════════════════════════════════════════════════════════════
//
//  NodeHello
//
//  Minimal Node.js unit. No DOM, no TElement, no browser globals.
//  Compiles to JavaScript that runs under: node output.js
//
//  DWScript's console external maps directly to Node's console object.
//  Variant dispatch handles require() and any Node API.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses NodeTypes;

procedure RunNode;

implementation

procedure RunNode;
var
  os, path: variant;
begin

  console.log('Hello from Shoestring on Node.js');
  //process.stdout.write('foo');

  //asm @os = require('os'); end;
  os := reqNodeModule('os');
  path := reqNodeModule('path');


  console.log('Platform: ' + String(os.platform()));
  console.log('Hostname: ' + String(os.hostname()));
  console.log('Home dir: ' + String(os.homedir()));
  console.log('CPUs:     ' + String(os.cpus().length));
  asm console.log('Uptime:   ' + String(os.uptime()) + 's'); end;
  console.log('Resolved: ' + String(path.resolve('.')));

end;

initialization
  RunNode;
end.