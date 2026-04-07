unit FormDemo;

// ═══════════════════════════════════════════════════════════════════════════
//
//  FormDemo — generic MySQL browser demo
//
//  On load: fetches all databases from server.js and populates a dropdown.
//  Connect button: connects to the selected database and shows the MySQL
//  version and active database name.
//
//  Requires server.js to be running:
//    MYSQL_HOST=127.0.0.1 MYSQL_USER=root MYSQL_PASSWORD=secret node server.js
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JForm, JElement, JPanel, JButton, JSelect;

type
  TFormDemo = class(TW3Form)
  private
    FSelect: JW3Select;
    FStatus: JW3Panel;
    procedure LoadDatabases;
    procedure HandleConnect(Sender: TObject);
  protected
    procedure InitializeObject; override;
  end;

implementation

uses Globals, HttpClient, ThemeStyles;

const
  ServerURL = 'http://localhost:3001';

{ TFormDemo }

procedure TFormDemo.InitializeObject;
begin
  inherited;

  SetStyle('display',         'flex');
  SetStyle('flex-direction',  'column');
  SetStyle('align-items',     'center');
  SetStyle('justify-content', 'center');
  SetStyle('gap',             'var(--space-5)');

  var Title := JW3Panel.Create(Self);
  Title.SetText('MySQL Browser');
  Title.SetStyle('font-size',   'var(--text-2xl)');
  Title.SetStyle('font-weight', 'var(--weight-semi)');

  var Card := JW3Panel.Create(Self);
  Card.SetStyle('display',        'flex');
  Card.SetStyle('flex-direction', 'column');
  Card.SetStyle('gap',            'var(--space-3)');
  Card.SetStyle('padding',        'var(--space-6)');
  Card.SetStyle('background',     'var(--surface-color)');
  Card.SetStyle('border',         '1px solid var(--border-color)');
  Card.SetStyle('border-radius',  'var(--radius-lg)');
  Card.SetStyle('min-width',      '320px');

  var Lbl := JW3Panel.Create(Card);
  Lbl.SetText('Select database');
  Lbl.AddClass(csFieldLabel);

  FSelect := JW3Select.Create(Card);
  FSelect.AddOption('', 'Loading…');

  var BtnConnect := JW3Button.Create(Card);
  BtnConnect.Caption := 'Connect';
  BtnConnect.AddClass(csBtnPrimary);
  BtnConnect.OnClick := HandleConnect;

  FStatus := JW3Panel.Create(Card);
  FStatus.SetStyle('font-size',  'var(--text-sm)');
  FStatus.SetStyle('min-height', '1.5em');

  LoadDatabases;
end;


procedure TFormDemo.LoadDatabases;
begin
  FetchJSON(ServerURL + '/databases',
    procedure(Data: variant)
    begin
      FSelect.ClearOptions;
      FSelect.AddOption('', 'Choose a database…');
      asm
        var sel  = (@FSelect).Handle;
        var dbs  = (@Data).databases || [];
        dbs.forEach(function(db) {
          var opt  = document.createElement('option');
          opt.value = db;
          opt.text  = db;
          sel.appendChild(opt);
        });
      end;
    end,
    procedure(Status: Integer; Msg: String)
    begin
      FSelect.ClearOptions;
      FSelect.AddOption('', 'Could not load databases');
      FStatus.SetText('Error ' + IntToStr(Status) + ': ' + Msg);
      FStatus.SetStyle('color', 'var(--color-danger)');
    end
  );
end;


procedure TFormDemo.HandleConnect(Sender: TObject);
var
  db: String;
begin
  db := FSelect.Value;

  if db = '' then
  begin
    FStatus.SetText('Please select a database first.');
    FStatus.SetStyle('color', 'var(--color-warning)');
    exit;
  end;

  FStatus.SetText('Connecting…');
  FStatus.SetStyle('color', 'var(--text-light)');

  FetchJSON(ServerURL + '/connect?db=' + db,
    procedure(Data: variant)
    var
      version: String;
      dbname:  String;
    begin
      asm
        @version = String((@Data).version || 'unknown');
        @dbname  = String((@Data).database || '');
      end;
      FStatus.SetText('Connected  ·  MySQL ' + version + '  ·  ' + dbname);
      FStatus.SetStyle('color', 'var(--color-success)');
    end,
    procedure(Status: Integer; Msg: String)
    begin
      FStatus.SetText('Error ' + IntToStr(Status) + ': ' + Msg);
      FStatus.SetStyle('color', 'var(--color-danger)');
    end
  );
end;

end.
