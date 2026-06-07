unit JListBox;

// ═══════════════════════════════════════════════════════════════════════════â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//
//  ListBox
//
//  A scrollable list of selectable items. Each item is a <div> inside a
//  scrolling container. Supports single selection. Items are added with
//  AddItem(value, text) and the selected value is readable/writable.
//
//  Usage:
//
//    var List := JW3ListBox.Create(Self);
//    List.AddItem('1', 'First item');
//    List.AddItem('2', 'Second item');
//    List.OnSelect := procedure(Sender: TObject; Value: String)
//    begin
//      console.log('Selected: ' + Value);
//    end;
//
//  CSS variables:
//
//    --lb-border          List border            default: 1px solid var(--border-color)
//    --lb-radius          List radius            default: var(--radius-md)
//    --lb-bg              List background        default: var(--surface-color)
//    --lb-item-padding    Item padding           default: 8px 12px
//    --lb-item-hover      Item hover bg          default: var(--hover-color)
//    --lb-item-selected   Selected item bg       default: var(--primary-color)
//    --lb-item-sel-color  Selected item text     default: #fff
//
// ═══════════════════════════════════════════════════════════════════════════•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

interface

uses JElement;

const
  csListBox         = 'listbox';
  csListBoxItem     = 'listbox-item';
  csListBoxSelected = 'listbox-selected';

type
  TListBoxSelectEvent = procedure(Sender: TObject; Value: String);

  JW3ListBox = class(TElement)
  private
    FItems:      array of TElement;
    FValues:     array of String;
    FSelIndex:   Integer;
    FOnSelect:   TListBoxSelectEvent;

    procedure HandleItemClick(Sender: TObject);

  public
    constructor Create(Parent: TElement); virtual;

    procedure AddItem(const Value, Text: String);
    procedure Clear;
    function  ItemCount: Integer;
    procedure Sort(Descending: Boolean = false);

    function  GetSelectedIndex: Integer;
    procedure SetSelectedIndex(Index: Integer);
    function  GetSelectedValue: String;

    property SelectedIndex: Integer read GetSelectedIndex write SetSelectedIndex;
    property SelectedValue: String read GetSelectedValue;
    property OnSelect: TListBoxSelectEvent read FOnSelect write FOnSelect;
  end;

procedure RegisterListBoxStyles;

implementation

uses Globals;

var FRegistered: Boolean := false;

procedure RegisterListBoxStyles;
begin
  if FRegistered then exit;
  FRegistered := true;

  AddStyleBlock(#'

    .listbox {
      overflow-y: auto;
      border: var(--lb-border, 1px solid var(--border-color, #e2e8f0));
      border-radius: var(--lb-radius, var(--radius-md, 6px));
      background: var(--lb-bg, var(--surface-color, #ffffff));
    }

    .listbox-item {
      flex-direction: row;
      align-items: center;
      padding: var(--lb-item-padding, 8px 12px);
      font-size: var(--font-size-sm, 0.875rem);
      color: var(--text-color, #334155);
      cursor: pointer;
      user-select: none;
      transition: background-color var(--anim-duration, 0.2s);
    }

    .listbox-item:hover {
      background: var(--lb-item-hover, var(--hover-color, #f1f5f9));
    }

    .listbox-selected {
      background: var(--lb-item-selected, var(--primary-color, #6366f1)) !important;
      color: var(--lb-item-sel-color, #ffffff);
    }
  ');
end;

{ JW3ListBox }

constructor JW3ListBox.Create(Parent: TElement);
begin
  inherited Create('div', Parent);
  AddClass(csListBox);
  FSelIndex := -1;
end;

procedure JW3ListBox.AddItem(const Value, Text: String);
var
  Item: TElement;
begin
  Item := TElement.Create('div', Self);
  Item.AddClass(csListBoxItem);
  Item.SetText(Text);
  Item.Tag := IntToStr(FItems.Count);
  Item.OnClick := HandleItemClick;

  FItems.Add(Item);
  FValues.Add(Value);
end;

procedure JW3ListBox.Clear;
begin
  inherited Clear;
  FItems.Clear;
  FValues.Clear;
  FSelIndex := -1;
end;

function JW3ListBox.ItemCount: Integer;
begin
  Result := FItems.Count;
end;

procedure JW3ListBox.HandleItemClick(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := StrToInt(TElement(Sender).Tag);
  SetSelectedIndex(Idx);
end;

function JW3ListBox.GetSelectedIndex: Integer;
begin
  Result := FSelIndex;
end;

procedure JW3ListBox.SetSelectedIndex(Index: Integer);
begin
  // Deselect previous
  if (FSelIndex >= 0) and (FSelIndex < FItems.Count) then
    FItems[FSelIndex].RemoveClass(csListBoxSelected);

  FSelIndex := Index;

  // Select new
  if (FSelIndex >= 0) and (FSelIndex < FItems.Count) then
  begin
    FItems[FSelIndex].AddClass(csListBoxSelected);

    if assigned(FOnSelect) then
      FOnSelect(Self, FValues[FSelIndex]);
  end;
end;

function JW3ListBox.GetSelectedValue: String;
begin
  if (FSelIndex >= 0) and (FSelIndex < FValues.Count) then
    Result := FValues[FSelIndex]
  else
    Result := '';
end;


// Sort -- re-order all items alphabetically by their display text.
//
//   List.Sort;           // ascending  (default)
//   List.Sort(true);     // descending
//
// Implementation notes:
//   - Pairs (display text, value) are sorted together so the value-to-text
//     mapping is always preserved.
//   - The current selection is remembered by value and restored afterward.
//   - The list is cleared and rebuilt, so DOM order matches sort order.

procedure JW3ListBox.Sort(Descending: Boolean = false);
var
  i:      Integer;
  Texts:  array of String;
  Vals:   array of String;
  SelVal: String;
begin
  if FItems.Count < 2 then exit;

  // -- Snapshot current texts and values ------------------------------------

  Texts := [];
  Vals  := [];
  for i := 0 to FItems.Count - 1 do
  begin
    Texts.Add(FItems[i].GetText);
    Vals.Add(FValues[i]);
  end;

  // -- Sort (text, value) pairs by text, case-insensitive -------------------

  asm
    var pairs = [];
    for (var k = 0; k < Texts.length; k++)
      pairs.push({ text: Texts[k], value: Vals[k] });

    pairs.sort(function(a, b) {
      var la = a.text.toLowerCase(), lb = b.text.toLowerCase();
      if (la < lb) return Descending ? 1 : -1;
      if (la > lb) return Descending ? -1 : 1;
      return 0;
    });

    for (var k = 0; k < pairs.length; k++) {
      Texts[k] = pairs[k].text;
      Vals[k]  = pairs[k].value;
    }
  end;

  // -- Remember selection by value so we can restore it --------------------

  SelVal := GetSelectedValue;

  // -- Rebuild in sorted order ----------------------------------------------

  Clear;
  for i := 0 to Texts.Count - 1 do
    AddItem(Vals[i], Texts[i]);

  // -- Restore the prior selection (by value, stable across re-orders) ------

  if SelVal <> '' then
    for i := 0 to FValues.Count - 1 do
      if FValues[i] = SelVal then
      begin
        SetSelectedIndex(i);
        break;
      end;
end;

initialization
  RegisterListBoxStyles;
end.
