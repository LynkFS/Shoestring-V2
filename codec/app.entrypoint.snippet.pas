// ═══════════════════════════════════════════════════════════════════════════
//   Lines to add to ShoeStringV2/app.entrypoint.pas
//
//   This is a snippet, not a full file — splice the bits below into the
//   existing entry point. Do not replace your existing file with this.
// ═══════════════════════════════════════════════════════════════════════════


// 1. Add the new units to the `uses` clause of app.entrypoint.pas.
//    Order matters: JCodec first (base), then the individual codecs,
//    then JPipeline (uses JCodec), then FormCodecs (uses all of them).

uses
  // ... your existing units ...
  JCodec,
  JCodecJSON,
  JCodecBase64,
  JCodecHex,
  JPipeline,
  FormCodecs;


// 2. Register the form with the application. Place this alongside the
//    other Application.CreateForm calls in your entry point.

Application.CreateForm('FormCodecs', TFormCodecs);


// 3. Switch the startup form to FormCodecs for testing. When you are
//    happy and want to go back to Kitchensink, just swap the argument.

Application.GoToForm('FormCodecs');
//Application.GoToForm('Kitchensink');


// ═══════════════════════════════════════════════════════════════════════════
//
//   After this, compile in Quartex Pascal IDE and open
//   ShoeStringV2/index.html. The sidebar gives you JSON / Base64 / Hex /
//   Pipeline / Type-check / Roadmap demos.
//
//   Node target: the codec units have zero DOM dependencies and will work
//   identically in a Node.js project. JCodecBase64 and JCodecHex
//   automatically detect and use the Node 'Buffer' class for performance.
//
// ═══════════════════════════════════════════════════════════════════════════