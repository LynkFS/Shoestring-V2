unit FormBooks;

// ═══════════════════════════════════════════════════════════════════════════
//  Books CRUD (action-based PHP API + MySQL)
//
//  Demonstrates TDBClient (JDB) and JW3Table together.
//  The table is declared once with columns and an OnDelete handler;
//  LoadBooks just calls FTable.SetRows(Data.rows).
//
//  API endpoint: https://lynkfs.com/db-connect/books_api.php
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JForm, JElement, JPanel, JButton, JInput, JDB, JTable;

type
  TFormBooks = class(TW3Form)
  private
    FDB:      TDBClient;
    FTable:   JW3Table;
    FStatus:  JW3Panel;
    FTitleIn: JW3Input;
    FAuthorIn:JW3Input;
    FPriceIn: JW3Input;
    FStockIn: JW3Input;

    procedure LoadBooks;
    procedure AddBook;
    procedure DeleteBook(const ID: String);
    procedure ShowStatus(const Msg: String; IsError: Boolean);
  protected
    procedure InitializeObject; override;
  end;

implementation

uses Globals, ThemeStyles, JToast;

{ TFormBooks }

procedure TFormBooks.InitializeObject;
begin
  inherited;

  FDB := TDBClient.Create('https://lynkfs.com/db-connect/books_api.php');

  SetStyle('display',        'flex');
  SetStyle('flex-direction', 'column');
  SetStyle('padding',        'var(--space-5)');
  SetStyle('gap',            'var(--space-4)');
  SetStyle('max-width',      '820px');
  SetStyle('margin',         '0 auto');

  // ── Header ────────────────────────────────────────────────────────────────

  var Header := JW3Panel.Create(Self);
  Header.SetStyle('display',         'flex');
  Header.SetStyle('align-items',     'center');
  Header.SetStyle('justify-content', 'space-between');

  var TitleEl := JW3Panel.Create(Header);
  TitleEl.SetText('Books');
  TitleEl.SetStyle('font-size',   'var(--text-xl)');
  TitleEl.SetStyle('font-weight', 'var(--weight-semi)');

  var BtnRefresh := JW3Button.Create(Header);
  BtnRefresh.Caption := 'Refresh';
  BtnRefresh.OnClick := lambda LoadBooks; end;

  // ── Status line ───────────────────────────────────────────────────────────

  FStatus := JW3Panel.Create(Self);
  FStatus.SetStyle('font-size',  'var(--text-sm)');
  FStatus.SetStyle('color',      'var(--text-light)');
  FStatus.SetStyle('min-height', '1.4em');

  // ── Table ─────────────────────────────────────────────────────────────────

  FTable := JW3Table.Create(Self);
  FTable.AddColumn('ID',     'id');
  FTable.AddColumn('Title',  'title');
  FTable.AddColumn('Author', 'author');
  FTable.AddColumn('Price',  'price');
  FTable.AddColumn('Stock',  'stock');
  FTable.OnDelete := procedure(ID: String)
  begin
    DeleteBook(ID);
  end;

  // ── Divider ───────────────────────────────────────────────────────────────

  var Sep := JW3Panel.Create(Self);
  Sep.SetStyle('border-top', '1px solid var(--border-color)');

  // ── Add book form ─────────────────────────────────────────────────────────

  var AddHeading := JW3Panel.Create(Self);
  AddHeading.SetText('Add a book');
  AddHeading.SetStyle('font-size',   'var(--text-base)');
  AddHeading.SetStyle('font-weight', 'var(--weight-semi)');

  var Grid := JW3Panel.Create(Self);
  Grid.SetStyle('display',               'grid');
  Grid.SetStyle('grid-template-columns', 'repeat(2, 1fr)');
  Grid.SetStyle('gap',                   'var(--space-3)');

  var TitleGrp := JW3Panel.Create(Grid);
  TitleGrp.AddClass(csFieldGroup);
  var TitleLbl := JW3Panel.Create(TitleGrp);
  TitleLbl.SetText('Title');
  TitleLbl.AddClass(csFieldLabel);
  FTitleIn := JW3Input.Create(TitleGrp);
  FTitleIn.Placeholder := 'Book title';

  var AuthorGrp := JW3Panel.Create(Grid);
  AuthorGrp.AddClass(csFieldGroup);
  var AuthorLbl := JW3Panel.Create(AuthorGrp);
  AuthorLbl.SetText('Author');
  AuthorLbl.AddClass(csFieldLabel);
  FAuthorIn := JW3Input.Create(AuthorGrp);
  FAuthorIn.Placeholder := 'Author name';

  var PriceGrp := JW3Panel.Create(Grid);
  PriceGrp.AddClass(csFieldGroup);
  var PriceLbl := JW3Panel.Create(PriceGrp);
  PriceLbl.SetText('Price');
  PriceLbl.AddClass(csFieldLabel);
  FPriceIn := JW3Input.Create(PriceGrp);
  FPriceIn.InputType   := 'number';
  FPriceIn.Placeholder := '0.00';

  var StockGrp := JW3Panel.Create(Grid);
  StockGrp.AddClass(csFieldGroup);
  var StockLbl := JW3Panel.Create(StockGrp);
  StockLbl.SetText('Stock');
  StockLbl.AddClass(csFieldLabel);
  FStockIn := JW3Input.Create(StockGrp);
  FStockIn.InputType   := 'number';
  FStockIn.Placeholder := '0';

  var BtnAdd := JW3Button.Create(Self);
  BtnAdd.Caption := 'Add book';
  BtnAdd.AddClass(csBtnPrimary);
  BtnAdd.SetStyle('align-self', 'flex-start');
  BtnAdd.OnClick := lambda AddBook; end;

  LoadBooks;
end;


procedure TFormBooks.ShowStatus(const Msg: String; IsError: Boolean);
begin
  FStatus.SetText(Msg);
  if IsError then
    FStatus.SetStyle('color', 'var(--color-danger)')
  else
    FStatus.SetStyle('color', 'var(--text-light)');
end;


procedure TFormBooks.LoadBooks;
begin
  ShowStatus('Loading…', false);
  FTable.Clear;

  FDB.Query('action=books_all',
    procedure(Data: variant)
    var cnt: Integer;
    begin
      FTable.SetRows(Data.rows);
      asm @cnt = ((@Data).rows || []).length; end;
      ShowStatus(IntToStr(cnt) + ' book(s)', false);
    end,
    procedure(Msg: String)
    begin
      ShowStatus(Msg, true);
    end
  );
end;


procedure TFormBooks.AddBook;
var title, author, price, stock, body: String;
begin
  title  := FTitleIn.Value;
  author := FAuthorIn.Value;
  price  := FPriceIn.Value;
  stock  := FStockIn.Value;

  if (title = '') or (author = '') then
  begin
    Toast('Title and Author are required.', ttWarning, 3000);
    exit;
  end;

  if price = '' then price := '0';
  if stock = '' then stock := '0';

  body := 'action=books_insert' +
    '&title='  + DBEncode(title)  +
    '&author=' + DBEncode(author) +
    '&price='  + DBEncode(price)  +
    '&stock='  + DBEncode(stock);

  FDB.Query(body,
    procedure(Data: variant)
    begin
      FTitleIn.Value  := '';
      FAuthorIn.Value := '';
      FPriceIn.Value  := '';
      FStockIn.Value  := '';
      Toast('Book added.', ttSuccess, 2000);
      LoadBooks;
    end,
    procedure(Msg: String)
    begin
      Toast('Error: ' + Msg, ttDanger, 4000);
    end
  );
end;


procedure TFormBooks.DeleteBook(const ID: String);
begin
  FDB.Query('action=books_delete&id=' + ID,
    procedure(Data: variant)
    begin
      Toast('Deleted.', ttSuccess, 2000);
      LoadBooks;
    end,
    procedure(Msg: String)
    begin
      Toast('Error: ' + Msg, ttDanger, 4000);
    end
  );
end;

end.
