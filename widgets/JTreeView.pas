unit JTreeView;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Tree View
//
//  A hierarchical tree with expand/collapse, keyboard navigation, lazy
//  loading, and ARIA roles. Nodes are added programmatically. Each node
//  has a text label, optional icon class, and optional child nodes.
//
//  Usage:
//
//    Tree := JW3TreeView.Create(Panel);
//
//    var Root := Tree.AddNode(nil, 'Documents');
//    var Work := Tree.AddNode(Root, 'Work');
//    Tree.AddNode(Work, 'Report.docx');
//    Tree.AddNode(Work, 'Budget.xlsx');
//    var Personal := Tree.AddNode(Root, 'Personal');
//    Tree.AddNode(Personal, 'Photos');
//
//    Tree.OnSelect := procedure(Sender: TObject; Node: TTreeNode)
//    begin
//      ShowToast('Selected: ' + Node.Text);
//    end;
//
//  Lazy loading:
//
//    var Server := Tree.AddNode(nil, 'Remote Files');
//    Server.IsLazy := true;
//    Server.OnExpand := procedure(Node: TTreeNode)
//    begin
//      FetchJSON('/api/files/' + Node.Tag,
//        procedure(Data: variant) begin
//          // Add children from data
//          Tree.AddNode(Node, Data.name);
//          Node.IsLazy := false;  // don't fire again
//        end, nil);
//    end;
//
//  Keyboard:
//
//    Up/Down      Move focus between visible nodes
//    Left         Collapse current node (or move to parent)
//    Right        Expand current node (or move to first child)
//    Enter/Space  Select the focused node
//
//  Structure:
//
//    JW3TreeView              .tree            role="tree"
//      └── TTreeNode          .tree-node       role="treeitem"
//            ├── row          .tree-row         (indent + toggle + label)
//            │     ├── toggle .tree-toggle      (▸ / ▾)
//            │     └── label  .tree-label
//            └── children     .tree-children    role="group" (hidden when collapsed)
//
//  CSS variables:
//
//    --tree-indent         Indent per level       default: 20px
//    --tree-row-height     Row height             default: 32px
//    --tree-row-padding    Row padding            default: 4px 8px
//    --tree-row-radius     Row border radius      default: var(--radius-sm)
//    --tree-toggle-width   Toggle button width    default: 20px
//    --tree-font-size      Font size              default: var(--font-size-sm)
//    --tree-focus-bg       Focused row bg         default: var(--hover-color)
//    --tree-selected-bg    Selected row bg        default: var(--primary-color)
//    --tree-selected-color Selected text colour   default: #fff
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement, JPanel, Types;

const
  csTree         = 'tree';
  csTreeNode     = 'tree-node';
  csTreeRow      = 'tree-row';
  csTreeToggle   = 'tree-toggle';
  csTreeLabel    = 'tree-label';
  csTreeChildren = 'tree-children';
  csTreeFocused  = 'tree-focused';
  csTreeSelected = 'tree-selected';
  csTreeExpanded = 'tree-expanded';

type
  TTreeNode = class;

  TTreeNodeEvent  = procedure(Node: TTreeNode);
  TTreeSelectEvent = procedure(Sender: TObject; Node: TTreeNode);

  TTreeNode = class
  public
    Text:       String;
    Tag:        String;
    IsLazy:     Boolean;
    OnExpand:   TTreeNodeEvent;

    // Internal — set by the tree
    Row:        JW3Panel;
    Toggle:     JW3Panel;
    LabelEl:    JW3Panel;
    ChildrenEl: JW3Panel;
    ParentNode: TTreeNode;
    Children:   array of TTreeNode;
    Depth:      Integer;
    Expanded:   Boolean;
    TreeView:   TObject;   // back-reference, typed as TObject to avoid circular
  end;

  JW3TreeView = class(TElement)
  private
    FNodes:     array of TTreeNode;   // flat list of all nodes in DOM order
    FFocusIdx:  Integer;
    FSelected:  TTreeNode;
    FOnSelect:  TTreeSelectEvent;

    procedure RenderNode(Node: TTreeNode; Container: TElement);
    procedure ToggleNode(Node: TTreeNode);
    procedure ExpandNode(Node: TTreeNode);
    procedure CollapseNode(Node: TTreeNode);
    procedure FocusNode(Index: Integer);
    procedure SelectNode(Node: TTreeNode);
    procedure RebuildFlatList;
    function  VisibleNodes: array of TTreeNode;
    procedure HandleKeyDown(EventObj: JEvent);

  public
    constructor Create(Parent: TElement); virtual;

    function  AddNode(ParentNode: TTreeNode; const Text: String): TTreeNode;
    procedure Clear;

    property Selected: TTreeNode read FSelected;
    property OnSelect: TTreeSelectEvent read FOnSelect write FOnSelect;
  end;

procedure RegisterTreeViewStyles;

implementation

uses Globals;

var FRegistered: Boolean := false;

procedure RegisterTreeViewStyles;
begin
  if FRegistered then exit;
  FRegistered := true;

  AddStyleBlock(#'

    /* ── Tree container ───────────────────────────────────────────── */

    .tree {
      overflow-y: auto;
      overflow-x: auto;
      outline: none;
      gap: 1px;
    }

    /* ── Node wrapper ─────────────────────────────────────────────── */

    .tree-node {
      gap: 0;
    }

    /* ── Row: toggle + label, one line ────────────────────────────── */

    .tree-row {
      flex-direction: row;
      align-items: center;
      min-height: var(--tree-row-height, 32px);
      padding: var(--tree-row-padding, 4px 8px);
      border-radius: var(--tree-row-radius, var(--radius-sm, 4px));
      cursor: pointer;
      user-select: none;
      transition: background-color var(--anim-duration, 0.15s);
    }

    .tree-row:hover {
      background: var(--tree-focus-bg, var(--hover-color, #f1f5f9));
    }

    /* ── Focus ring (keyboard) ────────────────────────────────────── */

    .tree-focused > .tree-row {
      background: var(--tree-focus-bg, var(--hover-color, #f1f5f9));
      outline: 2px solid var(--primary-color, #6366f1);
      outline-offset: -2px;
    }

    /* ── Selected state ───────────────────────────────────────────── */

    .tree-selected > .tree-row {
      background: var(--tree-selected-bg, var(--primary-color, #6366f1));
      color: var(--tree-selected-color, #ffffff);
    }

    .tree-selected > .tree-row .tree-toggle {
      color: var(--tree-selected-color, #ffffff);
    }

    /* ── Toggle button (▸ / ▾) ────────────────────────────────────── */

    .tree-toggle {
      flex-direction: row;
      align-items: center;
      justify-content: center;
      width: var(--tree-toggle-width, 20px);
      height: var(--tree-toggle-width, 20px);
      flex-shrink: 0;
      font-size: 0.85rem;
      color: var(--text-color, #334155);
      cursor: pointer;
      transition: transform var(--anim-duration, 0.15s);
    }

    .tree-expanded > .tree-row > .tree-toggle {
      transform: rotate(90deg);
    }

    /* ── Label ─────────────────────────────────────────────────────── */

    .tree-label {
      flex-direction: row;
      align-items: center;
      gap: 6px;
      font-size: var(--tree-font-size, var(--font-size-sm, 0.875rem));
      color: inherit;
      white-space: nowrap;
      min-width: 0;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    /* ── Children container ────────────────────────────────────────── */

    .tree-children {
      gap: 1px;
    }

    .tree-children.tree-collapsed {
      display: none;
    }
  ');
end;


{ JW3TreeView }

constructor JW3TreeView.Create(Parent: TElement);
begin
  inherited Create('div', Parent);
  AddClass(csTree);
  SetAttribute('role', 'tree');
  SetAttribute('tabindex', '0');

  FFocusIdx := -1;
  FSelected := nil;

  // Keyboard handling;
  Handle.addEventListener('keydown', @HandleKeyDown, false);
end;


//=============================================================================
// AddNode — creates a node and renders it
//=============================================================================

function JW3TreeView.AddNode(ParentNode: TTreeNode; const Text: String): TTreeNode;
var
  Node: TTreeNode;
  Container: TElement;
begin
  Node := TTreeNode.Create;
  Node.Text       := Text;
  Node.Tag        := '';
  Node.IsLazy     := false;
  Node.OnExpand   := nil;
  Node.ParentNode := ParentNode;
  Node.Depth      := 0;
  Node.Expanded   := false;
  Node.TreeView   := Self;

  if ParentNode <> nil then
  begin
    Node.Depth := ParentNode.Depth + 1;
    ParentNode.Children.Add(Node);

    // Parent now has children — show its toggle
    if ParentNode.Children.Count = 1 then
      ParentNode.Toggle.SetHTML('&#x25B8;');  // ▸

    Container := ParentNode.ChildrenEl;
  end
  else
    Container := Self;

  RenderNode(Node, Container);
  FNodes.Add(Node);
  RebuildFlatList;

  Result := Node;
end;


//=============================================================================
// RenderNode — creates DOM elements for a single node
//=============================================================================

procedure JW3TreeView.RenderNode(Node: TTreeNode; Container: TElement);
var
  NodeEl: JW3Panel;
  mNode: TTreeNode;
begin
  // Node wrapper
  NodeEl := JW3Panel.Create(Container);
  NodeEl.AddClass(csTreeNode);
  NodeEl.SetAttribute('role', 'treeitem');
  NodeEl.SetAttribute('aria-expanded', 'false');

  // Row (toggle + label)
  Node.Row := JW3Panel.Create(NodeEl);
  Node.Row.AddClass(csTreeRow);

  // Indent
  if Node.Depth > 0 then
    Node.Row.SetStyle('padding-left',
      'calc(' + IntToStr(Node.Depth) + ' * var(--tree-indent, 20px) + 8px)');

  // Toggle
  Node.Toggle := JW3Panel.Create(Node.Row);
  Node.Toggle.AddClass(csTreeToggle);
  // Empty until node gets children
  Node.Toggle.SetHTML('&nbsp;');

  // Click on toggle expands/collapses
  mNode := Node;

  Node.Toggle.OnClick := procedure(Sender: TObject)
  begin
    ToggleNode(mNode);
  end;

  // Label
  Node.LabelEl := JW3Panel.Create(Node.Row);
  Node.LabelEl.AddClass(csTreeLabel);
  Node.LabelEl.SetText(Node.Text);

  // Click on row selects
  Node.Row.OnClick := procedure(Sender: TObject)
  begin
    SelectNode(mNode);
  end;

  // Children container
  Node.ChildrenEl := JW3Panel.Create(NodeEl);
  Node.ChildrenEl.AddClass(csTreeChildren);
  Node.ChildrenEl.AddClass('tree-collapsed');  // CSS handles display:none
  Node.ChildrenEl.SetAttribute('role', 'group');
end;


//=============================================================================
// Expand / Collapse / Toggle
//=============================================================================

procedure JW3TreeView.ToggleNode(Node: TTreeNode);
begin
  if Node.Expanded then
    CollapseNode(Node)
  else
    ExpandNode(Node);
end;

procedure JW3TreeView.ExpandNode(Node: TTreeNode);
begin
  if Node.Expanded then exit;
  if (Node.Children.Count = 0) and (not Node.IsLazy) then exit;

  Node.Expanded := true;

  Node.ChildrenEl.RemoveClass('tree-collapsed');  // CSS class was hiding it

  // Update ARIA and visual state on the node wrapper (Row's parent)
  var NodeEl := Node.Row.Parent;
  if NodeEl <> nil then
  begin
    NodeEl.AddClass(csTreeExpanded);
    NodeEl.SetAttribute('aria-expanded', 'true');
  end;

  // Lazy loading callback
  if Node.IsLazy and assigned(Node.OnExpand) then
    Node.OnExpand(Node);

  RebuildFlatList;
end;

procedure JW3TreeView.CollapseNode(Node: TTreeNode);
begin
  if not Node.Expanded then exit;

  Node.Expanded := false;
  Node.ChildrenEl.AddClass('tree-collapsed');  // CSS class hides it

  var NodeEl := Node.Row.Parent;
  if NodeEl <> nil then
  begin
    NodeEl.RemoveClass(csTreeExpanded);
    NodeEl.SetAttribute('aria-expanded', 'false');
  end;

  RebuildFlatList;
end;


//=============================================================================
// Selection and focus
//=============================================================================

procedure JW3TreeView.SelectNode(Node: TTreeNode);
begin
  // Deselect previous
  if (FSelected <> nil) and (FSelected.Row <> nil) then
  begin
    var PrevEl := FSelected.Row.Parent;
    if PrevEl <> nil then
      PrevEl.RemoveClass(csTreeSelected);
  end;

  FSelected := Node;

  // Select new
  if (Node <> nil) and (Node.Row <> nil) then
  begin
    var NodeEl := Node.Row.Parent;
    if NodeEl <> nil then
      NodeEl.AddClass(csTreeSelected);
  end;

  // Focus this node in the flat list
  var Vis := VisibleNodes;
  for var i := 0 to Vis.Count - 1 do
    if Vis[i] = Node then
    begin
      FocusNode(i);
      break;
    end;

  if assigned(FOnSelect) then
    FOnSelect(Self, Node);
end;

procedure JW3TreeView.FocusNode(Index: Integer);
var
  Vis: array of TTreeNode;
begin
  Vis := VisibleNodes;
  if (Index < 0) or (Index >= Vis.Count) then exit;

  // Remove previous focus
  if (FFocusIdx >= 0) and (FFocusIdx < Vis.Count) then
  begin
    var PrevEl := Vis[FFocusIdx].Row.Parent;
    if PrevEl <> nil then
      PrevEl.RemoveClass(csTreeFocused);
  end;

  FFocusIdx := Index;

  // Apply focus
  var NodeEl := Vis[Index].Row.Parent;
  if NodeEl <> nil then
  begin
    NodeEl.AddClass(csTreeFocused);
    // Scroll into view
    var h := NodeEl.handle;
    asm NodeEl.scrollIntoView({ block: 'nearest' }); end;
  end;
end;


//=============================================================================
// Flat list of visible nodes (for keyboard navigation)
//=============================================================================

procedure CollectVisible(Node: TTreeNode; var List: array of TTreeNode);
begin
  List.Add(Node);
  if Node.Expanded then
    for var i := 0 to Node.Children.Count - 1 do
      CollectVisible(Node.Children[i], List);
end;

function JW3TreeView.VisibleNodes: array of TTreeNode;
begin
  Result := [];
  // Walk all root-level nodes
  for var i := 0 to FNodes.Count - 1 do
    if FNodes[i].ParentNode = nil then
      CollectVisible(FNodes[i], Result);
end;

procedure JW3TreeView.RebuildFlatList;
begin
  // FNodes is the master list of ALL nodes (for cleanup).
  // VisibleNodes is computed on demand from the tree structure.
  // Nothing to rebuild — VisibleNodes walks the tree each time.
  // This method exists as a hook for future optimisation (caching).
end;


//=============================================================================
// Keyboard navigation
//=============================================================================

procedure JW3TreeView.HandleKeyDown(EventObj: JEvent);
var
  Key: String;
  Vis: array of TTreeNode;
  Node: TTreeNode;
begin
  Key := EventObj.key;
  Vis := VisibleNodes;
  if Vis.Count = 0 then exit;

  // Clamp focus
  if FFocusIdx < 0 then FFocusIdx := 0;
  if FFocusIdx >= Vis.Count then FFocusIdx := Vis.Count - 1;
  Node := Vis[FFocusIdx];

  if Key = 'ArrowDown' then
  begin
    EventObj.preventDefault;
    if FFocusIdx < Vis.Count - 1 then
      FocusNode(FFocusIdx + 1);
  end

  else if Key = 'ArrowUp' then
  begin
    EventObj.preventDefault;
    if FFocusIdx > 0 then
      FocusNode(FFocusIdx - 1);
  end

  else if Key = 'ArrowRight' then
  begin
    EventObj.preventDefault;
    if (Node.Children.Count > 0) or Node.IsLazy then
    begin
      if not Node.Expanded then
        ExpandNode(Node)
      else
      begin
        // Move to first child
        Vis := VisibleNodes;
        if FFocusIdx + 1 < Vis.Count then
          FocusNode(FFocusIdx + 1);
      end;
    end;
  end

  else if Key = 'ArrowLeft' then
  begin
    EventObj.preventDefault;
    if Node.Expanded then
      CollapseNode(Node)
    else if Node.ParentNode <> nil then
    begin
      // Move to parent
      Vis := VisibleNodes;
      for var i := 0 to Vis.Count - 1 do
        if Vis[i] = Node.ParentNode then
        begin
          FocusNode(i);
          break;
        end;
    end;
  end

  else if (Key = 'Enter') or (Key = ' ') then
  begin
    EventObj.preventDefault;
    SelectNode(Node);
  end;
end;


//=============================================================================
// Clear
//=============================================================================

procedure JW3TreeView.Clear;
begin
  inherited Clear;
  for var i := 0 to FNodes.Count - 1 do
    FNodes[i].Free;
  FNodes.Clear;
  FFocusIdx := -1;
  FSelected := nil;
end;

initialization
  RegisterTreeViewStyles;
end.