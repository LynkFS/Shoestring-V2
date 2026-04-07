unit FormBooksRaw;

// Simple books form using the raw SQL API.
// Two operations: list all books (SELECT) and add a new book (INSERT).

interface

uses JForm, JElement, JPanel, JButton, JInput, JDB, JTable;

type
  TFormBooksRaw = class(TW3Form)
  private
    FDB:       TDBClient;
    FTitleIn:  JW3Input;
    FAuthorIn: JW3Input;
    FTable:    JW3Table;

    procedure LoadBooks;
    procedure AddBook;
  protected
    procedure InitializeObject; override;
  end;

implementation

uses Globals, JToast;

{ TFormBooksRaw }

procedure TFormBooksRaw.InitializeObject;
begin
  inherited;

  // Use raw_api_native.php for native MySQL, raw_api_docker.php for Docker MySQL
  FDB := TDBClient.Create('https://lynkfs.com/db-connect/raw_api_native.php');

  SetStyle('display',        'flex');
  SetStyle('flex-direction', 'column');
  SetStyle('padding',        'var(--space-5)');
  SetStyle('gap',            'var(--space-3)');
  SetStyle('max-width',      '600px');
  SetStyle('margin',         '0 auto');

  var Heading := JW3Panel.Create(Self);
  Heading.SetText('Books  ·  Raw SQL');
  Heading.SetStyle('font-size',   'var(--text-xl)');
  Heading.SetStyle('font-weight', 'var(--weight-semi)');

  FTitleIn := JW3Input.Create(Self);
  FTitleIn.Placeholder := 'Title';

  FAuthorIn := JW3Input.Create(Self);
  FAuthorIn.Placeholder := 'Author';

  var BtnAdd := JW3Button.Create(Self);
  BtnAdd.Caption := 'Insert';
  BtnAdd.AddClass(csBtnPrimary);
  BtnAdd.SetStyle('align-self', 'flex-start');
  BtnAdd.OnClick := lambda AddBook; end;

  var BtnLoad := JW3Button.Create(Self);
  BtnLoad.Caption := 'Load books';
  BtnLoad.SetStyle('align-self', 'flex-start');
  BtnLoad.OnClick := lambda LoadBooks; end;

  FTable := JW3Table.Create(Self);
  FTable.AddColumn('ID',     'id');
  FTable.AddColumn('Title',  'title');
  FTable.AddColumn('Author', 'author');

  LoadBooks;
end;


procedure TFormBooksRaw.LoadBooks;
begin
  FDB.Query('sql_statement=' + DBEncode('SELECT id, title, author FROM books ORDER BY title'),
    procedure(Data: variant)
    begin
      FTable.SetRows(Data.rows);
    end,
    procedure(Msg: String)
    begin
      Toast('Load failed: ' + Msg, ttDanger, 4000);
    end
  );
end;


procedure TFormBooksRaw.AddBook;
var title, author, sql: String;
begin
  title  := FTitleIn.Value;
  author := FAuthorIn.Value;

  if (title = '') or (author = '') then
  begin
    Toast('Title and Author are required.', ttWarning, 3000);
    exit;
  end;

  // Escape single quotes for inline SQL — sufficient for a personal tool.
  // Use books_api.php with prepared statements for public-facing apps.
//  asm
//    var t = @title;
//    var a = @author;
//    t = t.replace(/'/g, "''");
//    a = a.replace(/'/g, "''");
//    @sql = "INSERT INTO books (title, author) VALUES ('" + t + "', '" + a + "')";
//  end;

  sql := "INSERT INTO books (title, author) VALUES ('" + title + "', '" + author + "')";

  FDB.Query('sql_statement=' + DBEncode(sql),
    procedure(Data: variant)
    begin
      FTitleIn.Value  := '';
      FAuthorIn.Value := '';
      Toast('Book added.', ttSuccess, 2000);
      LoadBooks;
    end,
    procedure(Msg: String)
    begin
      Toast('Insert failed: ' + Msg, ttDanger, 4000);
    end
  );
end;

end.
