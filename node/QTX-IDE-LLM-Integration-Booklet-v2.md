# QTX IDE — LLM Integration

## Bridging Intelligent Code Assistance with Object Pascal Web Development

---

> *"The future of development isn't about replacing programmers—it's about augmenting their capabilities with intelligent tools that understand context, learn from mistakes, and grow alongside your codebase."*

---

## Welcome

This booklet introduces three ways to integrate the QTX IDE with Claude Code, Anthropic's AI-powered coding assistant:

1. **IDE Mode** ⭐ — Connect directly to the QTX IDE's built-in MCP server. Full integration with compilation, file editing, code intelligence, and documentation — all native. Requires the IDE to be running.

2. **Simple Mode** — Use a knowledge file to teach Claude about QTX patterns and conventions. Works on any platform, no setup required beyond copying a single file. You compile manually.

3. **Adaptive Mode** — Install a separate MCP server that triggers compilation via PowerShell automation. Windows only, requires Node.js. A workaround for when IDE Mode isn't available.

All approaches can use the knowledge file (`claude.md`) which captures QTX-specific patterns, RTL usage, and learnings from your development sessions.

Whether you want the full native integration or a quick start, this guide will walk you through everything you need to know.

---

## Table of Contents

1. [What is QTX?](#what-is-qtx)
2. [The Vision: AI-Assisted QTX Development](#the-vision)
3. [Architecture Overview](#architecture-overview)
4. [Installation Guide](#installation-guide)
5. [Configuration](#configuration)
6. [Using the Integration](#using-the-integration)
7. [The Learning System](#the-learning-system)
8. [Best Practices](#best-practices)
9. [Troubleshooting](#troubleshooting)
10. [Appendix: MCP Tool Reference](#appendix)

---

## What is QTX?

QTX (Quartex Pascal) is a development platform that brings the elegance and structure of Object Pascal to modern web development. Built on DWScript, it compiles Object Pascal moulded into a comprehensive RTL into JavaScript, enabling you to build sophisticated browser and Node.js applications using familiar Pascal paradigms.

**Key Features of QTX:**

- **Object Pascal Syntax** — Write in the language you love, with classes, interfaces, and strong typing
- **JavaScript Output** — Compile to optimised JavaScript that runs anywhere
- **Integrated IDE** — The `dwc.exe` development environment with visual designers
- **Rich RTL** — A comprehensive Runtime Library for web application development
- **Dual Target** — Build for both browser and Node.js from the same codebase

```pascal
unit form1;

interface

uses
  qtx.sysutils,
  qtx.classes,
  qtx.dom.widgets,
  qtx.dom.forms,
  qtx.dom.control.button;

type
  Tform1 = class(TQTXForm)
  public
    constructor Create(AOwner: TQTXComponent; CB: TQTXFormConstructor); override;
  end;

implementation

constructor Tform1.Create(AOwner: TQTXComponent; CB: TQTXFormConstructor);
begin
  inherited Create(AOwner, procedure (Form: TQTXForm)
  begin
    {$I "impl::form1"}
    
    var MyButton := TQTXButton.Create(Self, procedure (Button: TQTXButton)
    begin
      Button.Left := 50;
      Button.Top := 10;
      Button.Width := 120;
      Button.Height := 30;
      Button.InnerHtml := 'Hello, QTX!';
      
      Button.OnClick := procedure (Sender: TObject)
      begin
        Application.ShowForm('form2', fdFromRight);
      end;
    end);
    
    if assigned(CB) then
      CB(Self);
  end);
end;

end.
```

---

## The Vision: AI-Assisted QTX Development

Modern AI coding assistants like Claude are powerful, but they have a limitation: they're trained on general programming knowledge and may not understand the nuances of specialised frameworks like QTX. The QTX RTL has its own patterns, class hierarchies, and idioms that differ from standard JavaScript or Delphi.

**The Problem:**
- Claude doesn't inherently know QTX-specific classes and methods
- Generic Pascal or JavaScript suggestions may not work with the QTX RTL
- Developers spend time explaining framework specifics repeatedly

**Our Solution — Three Approaches:**

| | IDE Mode ⭐ | Simple Mode | Adaptive Mode |
|---|------------|-------------|---------------|
| **How it works** | Native MCP server built into QTX IDE | Knowledge file teaches Claude the patterns | External MCP server with PowerShell automation |
| **Compilation** | Claude compiles directly | Manual (Ctrl+F9 in IDE) | Claude triggers via keystrokes |
| **File editing** | Claude edits files in IDE | You edit manually | You edit manually |
| **Code intelligence** | Symbol search, unit interfaces, docs | Knowledge file only | Knowledge file only |
| **Error feedback** | Direct from compiler | You paste into chat | Captured via clipboard |
| **Platform** | Any (IDE must be running) | Any | Windows only |
| **Setup** | One command | Copy one file | Install Node.js + configure MCP |

**Recommendation:** Use IDE Mode when the QTX IDE is running — it gives you the full integration. Fall back to Simple Mode for quick questions or when working on other platforms.

---

## Architecture Overview

### IDE Mode Architecture ⭐

```
┌─────────────────────────────────────────────────────────────────┐
│                       CLAUDE CODE                               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  "Compile and fix any errors"                           │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ MCP Protocol (HTTP)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                 QTX IDE BUILT-IN MCP SERVER                     │
│                   http://127.0.0.1:3030/mcp                     │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  File Operations:                                       │   │
│  │    get_file, set_file, edit_file, create_file, etc.    │   │
│  │                                                         │   │
│  │  Compilation:                                           │   │
│  │    compile, get_errors, get_build_files                 │   │
│  │                                                         │   │
│  │  Code Intelligence:                                     │   │
│  │    search_symbols, get_unit_interface, kb_index_*       │   │
│  │                                                         │   │
│  │  Documentation:                                         │   │
│  │    doc_search, doc_read, doc_lookup                     │   │
│  │                                                         │   │
│  │  Project Management:                                    │   │
│  │    run_project, stop_project, get_output                │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ Direct integration
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     DWC.EXE (QTX IDE)                           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  • Native compilation                                   │   │
│  │  • File editing synced with Claude                      │   │
│  │  • Symbol database and code intelligence                │   │
│  │  • Built-in documentation                               │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

**IDE Mode:** Claude connects directly to the QTX IDE's built-in MCP server. Full native integration — no workarounds needed.

---

### Simple Mode Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                       CLAUDE CODE                               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  "Help me create a new form with a listbox"             │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ Reads automatically
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       claude.md                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  # QTX Framework Coding Patterns - Knowledge Base       │   │
│  │                                                         │   │
│  │  ## Syntax                                              │   │
│  │  - In asm blocks, use @FieldName without Self prefix    │   │
│  │                                                         │   │
│  │  ## RTL                                                 │   │
│  │  - TQTXButton.OnClick uses procedure(Sender: TObject)   │   │
│  │  - TQTXListBox is in unit qtx.dom.control.listbox       │   │
│  │                                                         │   │
│  │  ...patterns and conventions...                         │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ You compile manually
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     DWC.EXE (QTX IDE)                           │
│                        Ctrl+F9                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Simple Mode:** Claude reads the knowledge file and helps you write correct QTX code. You compile manually in the IDE.

---

### Adaptive Mode Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                       CLAUDE CODE                               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  "Compile my QTX project and fix any errors"            │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ MCP Protocol (stdio transport)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              QTX ADAPTIVE MCP SERVER (index.ts)                 │
│  ┌──────────────────┐    ┌──────────────────────────────────┐  │
│  │  compile         │    │  update_knowledge                │  │
│  │  ─────────       │    │  ────────────────                │  │
│  │  Triggers build  │    │  Adds facts to claude.md         │  │
│  │  via PowerShell  │    │  Categories: syntax, rtl,        │  │
│  │  Returns errors  │    │  compiler, debugging, optimization│  │
│  └──────────────────┘    └──────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ PowerShell Automation
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              improved-compile.ps1 (Windows)                     │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  • Finds dwc.exe process                                │   │
│  │  • Activates IDE window                                 │   │
│  │  • Sends Ctrl+F9 to trigger compilation                 │   │
│  │  • Waits for index.js to be written                     │   │
│  │  • Presses F4 to switch to console output               │   │
│  │  • Copies output to clipboard                           │   │
│  │  • Returns JSON result                                  │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     DWC.EXE (QTX IDE)                           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  • Receives Ctrl+F9 compile command                     │   │
│  │  • Compiles DWScript → JavaScript                       │   │
│  │  • Writes output to index.js                            │   │
│  │  • Displays results in console pane                     │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       claude.md                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  # QTX Framework Coding Patterns - Knowledge Base       │   │
│  │  (Included automatically when compilation fails)        │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

**Adaptive Mode:** Claude triggers compilation via PowerShell automation. A workaround when IDE Mode isn't available. The knowledge file is automatically included in error responses.

---

**Component Summary:**

| Component | File/URL | Used In |
|-----------|----------|---------|
| **Claude Code** | — | All modes |
| **QTX IDE** | `dwc.exe` | All modes |
| **IDE MCP Server** | `http://127.0.0.1:3030/mcp` | IDE Mode |
| **Knowledge Base** | `claude.md` | Simple + Adaptive modes |
| **Adaptive MCP Server** | `index.ts` | Adaptive mode only |
| **Compile Script** | `improved-compile.ps1` | Adaptive mode only |

---

## Installation Guide

There are three ways to use this integration:

1. **IDE Mode** ⭐ — Connect to the QTX IDE's built-in MCP server (recommended)
2. **Simple Mode** — Just use the knowledge file with Claude Code
3. **Adaptive Mode** — Install the external MCP server for PowerShell-based compilation

---

### Option 1: IDE Mode (Built-in MCP Server) ⭐

This is the recommended approach. The QTX IDE has a built-in MCP server that provides full integration — compilation, file editing, code intelligence, and documentation.

**Prerequisites:**
- QTX IDE running with a project open
- Claude Code CLI installed

**Steps:**

1. Start the QTX IDE and open your project. The IDE will display:
   ```
   MCP server started @ 127.0.0.1:3030
   ```

2. Add the IDE's MCP server to Claude Code:
   ```bash
   claude mcp add --transport http qtx-ide http://127.0.0.1:3030/mcp
   ```

3. Verify the connection:
   ```bash
   claude mcp list
   ```
   You should see:
   ```
   qtx-ide: http://127.0.0.1:3030/mcp (HTTP) - ✓ Connected
   ```

4. Start Claude Code in your project directory and you'll have access to all IDE tools:
   - `compile` / `get_errors` — Compilation
   - `get_file` / `set_file` / `edit_file` — File editing
   - `search_symbols` / `get_unit_interface` — Code intelligence
   - `doc_search` / `doc_lookup` — Documentation
   - `run_project` / `stop_project` — Execution

**Advantages:**
- Full native integration
- Direct file editing synced with IDE
- Code intelligence and symbol search
- Built-in documentation access
- No external dependencies

**Limitations:**
- QTX IDE must be running
- Connection lost when IDE closes

---

### Option 2: Simple Mode (Knowledge File Only)

This is the easiest approach. You simply point Claude Code at your QTX project directory and give it access to the knowledge file. Claude can then help you write QTX code using the documented patterns, but you'll compile manually in the IDE.

**Steps:**

1. Download the integration package: **[adaptive-mcp-server.zip](adaptive-mcp-server.zip)**

2. Extract just the `claude.md` file and copy it to your QTX project directory

3. Open Claude Code in your project directory:
   ```bash
   cd /path/to/your/qtx-project
   claude
   ```

4. Claude will automatically read the `claude.md` file and use it as context for helping you write QTX code

**Advantages:**
- Works on any platform (Windows, macOS, Linux)
- No Node.js or MCP setup required
- No dependencies to install

**Limitations:**
- No automatic compilation from Claude Code
- You must compile manually in the QTX IDE (Ctrl+F9)
- Claude won't see compilation errors directly

---

### Option 3: Adaptive Mode (External MCP Server)

This option installs a separate MCP server that triggers compilation via PowerShell automation. Use this as a fallback when IDE Mode isn't available (e.g., older IDE versions without built-in MCP support).

#### Prerequisites

Before you begin, ensure you have:

- ✅ QTX IDE (`dwc.exe`) installed and licensed
- ✅ Claude Code CLI installed
- ✅ Node.js v18 or later
- ✅ Windows (PowerShell automation is Windows-specific)

#### Download

**[Download adaptive-mcp-server.zip](adaptive-mcp-server.zip)**

#### Step 1: Extract the Package

```powershell
# Navigate to your preferred installation directory
cd C:\Development

# Extract the integration package
Expand-Archive -Path adaptive-mcp-server.zip -DestinationPath .

# Enter the directory
cd adaptive-mcp-server
```

The extracted contents:

```
adaptive-mcp-server/
├── index.ts                    # Main MCP server source
├── package.json                # Node.js dependencies
├── package-lock.json           # Dependency lock file
├── tsconfig.json               # TypeScript configuration
├── claude.md                   # Knowledge base (copy to your project)
└── build/
    ├── index.js                # Compiled JavaScript
    ├── index.js.map            # Source map
    ├── index.d.ts              # Type definitions
    └── improved-compile.ps1    # PowerShell compile script
```

#### Step 2: Install Dependencies

```powershell
# Install Node.js dependencies
npm install
```

This installs:
- `@modelcontextprotocol/sdk` — The MCP protocol SDK
- `zod` — Schema validation library

#### Step 3: Build the Server (if needed)

The package includes pre-built files, but if you modify `index.ts`:

```powershell
# Compile TypeScript to JavaScript
npm run build

# Or watch for changes during development
npm run watch
```

#### Step 4: Set PowerShell Execution Policy

The compile script requires PowerShell to allow script execution:

```powershell
# Run this once in an elevated PowerShell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### Step 5: Register with Claude Code

Add the MCP server to Claude Code's configuration. The configuration location depends on your setup:

**Claude Desktop:** `%APPDATA%\Claude\claude_desktop_config.json`  
**Claude Code:** Check `claude mcp` command or your MCP settings

Example configuration:

```json
{
  "mcpServers": {
    "qtx-compiler": {
      "command": "node",
      "args": ["C:\\Development\\adaptive-mcp-server\\build\\index.js"],
      "env": {
        "QTX_PROJECT_ROOT": "C:\\QTXProjects\\MyApp"
      }
    }
  }
}
```

> **Important:** Replace the paths with your actual installation and project directories.

#### Step 6: Verify the Installation

1. **Ensure dwc.exe is running** with your project open
2. **Start Claude Code** in your project directory
3. **Test the connection:**

```
> What tools do you have access to?
```

Claude should list `compile` and `update_knowledge` among its available tools.

---

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `QTX_PROJECT_ROOT` | Root directory of your QTX project | Current working directory |

### Server Configuration (in index.ts)

The server uses these configuration paths:

```typescript
const config: ServerConfig = {
  projectRoot: process.env.QTX_PROJECT_ROOT || process.cwd(),
  powershellScript: path.resolve(__dirname, "improved-compile.ps1"),
  knowledgeBase: path.join(process.cwd(), "claude.md")
};
```

| Setting | Description |
|---------|-------------|
| `projectRoot` | Where to look for project files |
| `powershellScript` | Path to the PowerShell compile script |
| `knowledgeBase` | Path to the claude.md knowledge file |

### PowerShell Script Configuration

The `improved-compile.ps1` script has these settings:

| Setting | Value | Description |
|---------|-------|-------------|
| **Compile Timeout** | 30 seconds | Maximum wait for compilation |
| **Compile Trigger** | Ctrl+F9 | Keyboard shortcut sent to IDE |
| **Console Pane** | F4 | Key to switch to output pane |
| **Success Detection** | "Done" in output | How success is determined |
| **Error Detection** | "Error" or "terminated with errors" | How errors are detected |

---

## Using the Integration

### Starting a Session

1. **Launch the QTX IDE (dwc.exe):**
   Open your project in the IDE. The IDE must be running and visible for the automation to work.

2. **Open Claude Code in your project directory:**
   ```powershell
   cd C:\QTXProjects\MyApp
   claude
   ```

3. **Verify the connection:**
   ```
   > Do you have access to the QTX compile tool?
   ```

### Basic Compilation Workflow

**Simple Compile:**
```
> Compile my QTX project
```

Claude invokes the compile tool, which:
1. Activates the dwc.exe window
2. Sends Ctrl+F9 to trigger compilation
3. Waits for the output file to be written
4. Captures the console output
5. Returns the result

**Successful Output:**
```
### Compilation Successful

**Method Used:** UI Automation
**Status:** Done

**Compiler Output:**
```
Compiling project...
Writing index.js (245,312 bytes)
Done
```
```

**Error Output:**
```
### QTX Knowledge Base

[Contents of claude.md displayed here for context]

---

### Compilation Failed

**Method Used:** UI Automation

**Output:**
```
Compiling project...
Error: form1.pas(45): Unknown identifier 'TQTXPnael'
Compilation terminated with errors
```
```

### Example Session

```
You: I've added a new panel but the code won't compile. Can you check what's wrong?

Claude: I'll compile your project now.

        [Invoking compile tool...]

        The compilation failed with this error:

        Error: form1.pas(45): Unknown identifier 'TQTXPnael'

        This is a typo - you've written 'TQTXPnael' but the correct class name 
        is 'TQTXPanel'. Also, make sure you have the unit imported:

        ```pascal
        uses
          qtx.dom.control.panel;
        ```

        Would you like me to fix this in your code?

You: Yes please.

Claude: [Makes the fix...]
        [Invoking compile tool...]

        ### Compilation Successful

        **Method Used:** UI Automation
        **Status:** Done

        The typo has been fixed and your project compiles successfully.

        This is a good learning moment. Should I add a note about 
        TQTXPanel to the knowledge base?

You: Yes, add it.

Claude: [Invoking update_knowledge tool with category "rtl"...]

        Added to rtl:
        - TQTXPanel is in unit qtx.dom.control.panel - common typo: TQTXPnael
```

### The Compilation Flow

When you ask Claude to compile, here's what happens behind the scenes:

```
┌──────────────────────────────────────────────────────────────────┐
│ 1. Claude receives your request                                 │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│ 2. MCP Server executes improved-compile.ps1                     │
│    powershell -File "improved-compile.ps1"                      │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│ 3. PowerShell finds and activates dwc.exe                       │
│    Get-Process "dwc"                                            │
│    WScript.Shell.AppActivate(process.Id)                        │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│ 4. Sends Ctrl+F9 to trigger compilation                         │
│    [System.Windows.Forms.SendKeys]::SendWait("^{F9}")           │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│ 5. Monitors for completion (up to 30 seconds)                   │
│    Checks if index.js was recently modified                     │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│ 6. Captures console output                                      │
│    F4 → Ctrl+Home → Ctrl+Shift+End → Ctrl+C                    │
│    Get-Clipboard                                                │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│ 7. Returns JSON result to MCP Server                            │
│    { success: true/false, output: "...", method: "..." }        │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│ 8. If error, Claude reads claude.md for context                 │
│    Then presents the error with suggestions                     │
└──────────────────────────────────────────────────────────────────┘
```

---

## The Learning System

### How claude.md Works

The `claude.md` file is the heart of the learning system. When compilation fails, the MCP server automatically includes the contents of this file in its response to Claude, providing context for understanding and fixing errors.

**The Knowledge Categories:**

| Category | What It Contains |
|----------|-----------------|
| `syntax` | Language syntax rules, asm block patterns |
| `rtl` | Runtime Library classes and methods |
| `compiler` | Compiler behaviour and quirks |
| `debugging` | Debugging techniques and tips |
| `optimization` | Performance patterns |

**Structure of claude.md:**

```markdown
# QTX Framework Coding Patterns - Knowledge Base

## Overview
This document captures the proven patterns for building multi-form 
web applications using the QTX framework.

---

## Syntax

- In asm blocks, access class fields using @FieldName WITHOUT Self prefix
- To disable buttons in asm: (@FButton).handle.setAttribute('disabled','')

## RTL

- TQTXButton.OnClick signature: procedure (Sender: TObject)
- TQTXPanel is in unit qtx.dom.control.panel

## Compiler

- Emoji characters may be replaced by the compiler
- Complex emojis like 🥬 are converted to simpler symbols

## Debugging

## Optimization

---
*Last updated: 2026-01-28*
```

### Adding Knowledge

**Via the update_knowledge tool:**

```
You: Add to the knowledge base that TQTXListBox.AddText() is used 
     to populate list items.

Claude: [Invoking update_knowledge tool...]
        category: "rtl"
        fact: "TQTXListBox.AddText() is used to populate list items"

        Added to rtl:
        - TQTXListBox.AddText() is used to populate list items
```

**Automatic suggestions:**

After fixing compilation errors, Claude may suggest adding the learning:

```
Claude: I notice this is the second time we've encountered the 
        cpRelative positioning issue. Should I add this pattern 
        to the knowledge base?

You: Yes

Claude: [Invoking update_knowledge tool...]
```

### Knowledge Categories in Detail

**Syntax** — Language-level patterns:
- asm block field access rules
- Callback-based component creation
- Event handler signatures

**RTL** — Framework classes and methods:
- Unit dependencies (which class is in which unit)
- Method signatures and usage patterns
- Property access patterns

**Compiler** — Compiler-specific behaviours:
- Character encoding issues
- Compilation order requirements
- Include directive patterns

**Debugging** — Problem-solving patterns:
- Common error messages and fixes
- Debugging techniques
- Console output interpretation

**Optimization** — Performance patterns:
- Efficient DOM access
- Event handler best practices
- Memory management

---

## Best Practices

### For Effective AI-Assisted Development

1. **Keep the IDE Visible**
   The PowerShell automation needs to activate the dwc.exe window. Minimised or hidden windows may cause issues.

2. **Let Claude Learn**
   When Claude fixes something, allow it to add the learning to claude.md. The knowledge compounds over time.

3. **Be Specific About Errors**
   Instead of "it doesn't work," try:
   ```
   > The compile fails with "Unknown identifier" on line 45
   ```

4. **Review the Knowledge Base**
   ```
   > Show me what's in the QTX knowledge base for RTL
   ```

### For Project Organisation

1. **One claude.md Per Project**
   Keep project-specific knowledge in your project directory.

2. **Commit claude.md to Version Control**
   Share the accumulated knowledge with your team:
   ```bash
   git add claude.md
   git commit -m "Update QTX knowledge base"
   ```

3. **Start New Projects with a Template**
   Copy the base claude.md to new projects to preserve general QTX knowledge.

### For Team Collaboration

1. **Merge Knowledge Files**
   When team members discover new patterns, merge their claude.md learnings.

2. **Document Team Conventions**
   Add your team's coding standards to claude.md:
   ```
   > Add to syntax: Our team convention is to prefix all form 
   > fields with 'F' (e.g., FButton, FPanel)
   ```

---

## Troubleshooting

### Connection Issues

**Problem:** Claude doesn't see the QTX tools

**Solutions:**

1. Verify the MCP server configuration path is correct
2. Check that the build exists:
   ```powershell
   dir C:\Development\adaptive-mcp-server\build\index.js
   ```
3. Restart Claude Code after configuration changes

---

**Problem:** "dwc.exe is running but has no main window"

**Solutions:**

1. Ensure the QTX IDE is not minimised to system tray
2. Restore the IDE window to visible state
3. Try closing and reopening the IDE

---

### Compilation Issues

**Problem:** "Could not activate dwc.exe window"

**Solutions:**

1. Ensure only one instance of dwc.exe is running
2. Close any dialogs or popups in the IDE
3. Try clicking on the IDE window manually first

---

**Problem:** "PowerShell execution policy is too restrictive"

**Solution:**

Run this command once in an elevated PowerShell:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

**Problem:** "Compilation wait timeout reached"

**Solutions:**

1. Check if the IDE is showing a dialog box
2. Look for very large projects that take longer to compile
3. Check if the IDE is responding (not frozen)

---

**Problem:** "No output captured from console"

**Solutions:**

1. Manually press F4 in the IDE to verify the console pane works
2. Check that the console pane has content
3. Try compiling manually first to ensure it works

---

### Knowledge Base Issues

**Problem:** "No knowledge base found yet"

This is normal for new projects. The server creates a template when you first add knowledge:

```
> Add to syntax: Always call inherited first in constructors
```

---

**Problem:** Knowledge not appearing in error context

**Solutions:**

1. Verify claude.md exists in the current working directory
2. Check file permissions
3. Ensure the filename is exactly `claude.md` (lowercase)

---

## Appendix: MCP Tool Reference

### compile

Triggers compilation of the current QTX project using PowerShell automation.

**Parameters:** None

**Behaviour:**

1. Locates the `dwc.exe` process
2. Activates its window
3. Sends Ctrl+F9 to trigger compilation
4. Waits for index.js to be written (up to 30 seconds)
5. Captures console output via clipboard
6. Determines success based on output content

**Returns on Success:**

```json
{
  "content": [{
    "type": "text",
    "text": "### Compilation Successful\n\n**Method Used:** UI Automation\n**Status:** Done\n\n**Compiler Output:**\n```\nCompiling...\nDone\n```"
  }]
}
```

**Returns on Compilation Error:**

```json
{
  "isError": true,
  "content": [
    {
      "type": "text",
      "text": "### QTX Knowledge Base\n\n[contents of claude.md]\n\n---\n"
    },
    {
      "type": "text",
      "text": "### Compilation Failed\n\n**Method Used:** UI Automation\n\n**Output:**\n```\nError: Unknown identifier...\n```"
    }
  ]
}
```

> **Note:** When compilation fails, the knowledge base is automatically included in the response to give Claude context for fixing the error.

---

### update_knowledge

Adds a fact to the QTX knowledge base (claude.md).

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `category` | enum | Yes | One of: `syntax`, `rtl`, `compiler`, `debugging`, `optimization` |
| `fact` | string | Yes | The knowledge to add |

**Example Usage:**

```
category: "rtl"
fact: "TQTXPanel is in unit qtx.dom.control.panel"
```

**Returns:**

```json
{
  "content": [{
    "type": "text",
    "text": "Added to rtl:\n- TQTXPanel is in unit qtx.dom.control.panel"
  }]
}
```

**Behaviour:**

1. Reads existing claude.md (or creates template if missing)
2. Finds the category section
3. Appends the new fact as a bullet point
4. Saves the updated file

**Template Created for New Files:**

```markdown
# QTX Knowledge Base

## Syntax

## RTL

## Compiler

## Debugging

## Optimization

---
*Last updated: [current date]*
```

---

## Quick Reference Card

### Keyboard Shortcuts (QTX IDE)

| Shortcut | Action |
|----------|--------|
| Ctrl+F9 | Compile project |
| F4 | Switch to console output pane |

### Common Claude Commands

| Command | What It Does |
|---------|--------------|
| "Compile" | Triggers project compilation |
| "Compile and fix errors" | Compiles, analyses errors, suggests fixes |
| "Add to knowledge: [fact]" | Adds to the knowledge base |
| "What do you know about [topic]?" | Queries the knowledge base |

### Knowledge Categories

| Category | Use For |
|----------|---------|
| `syntax` | Language patterns, asm blocks |
| `rtl` | Classes, methods, units |
| `compiler` | Compiler quirks, encoding |
| `debugging` | Error patterns, fixes |
| `optimization` | Performance tips |

---

## Closing Thoughts

The integration of AI assistance with specialised development environments like QTX is sort of new in software development. By creating a feedback loop where the AI learns from real compilation errors and developer corrections, we build a system that becomes more valuable over time.

With IDE Mode, you get the best experience — direct integration with compilation, file editing, code intelligence, and documentation. The Adaptive Mode using virtual keystrokes remains available as a fallback for older IDE versions, but the native MCP server built into the QTX IDE is the recommended approach.

The claude.md knowledge base is more than just documentation—it's a living record of your project's accumulated wisdom, accessible to both human developers and AI assistants alike.

Note that the distributed knowledge file is far from perfect. For instance, if you create a form through the chat interface, it will do so but will not create a layout file and all components will be created in code. However if you do create a layout file manually, it will compile as per usual. There are many other rules in there which reflect my coding style. That might be different from yours.

The good thing is that Claude becomes increasingly knowledgeable about QTX patterns, your project's conventions, and your specific coding style. Adaptive AI assistance.

---

**Version:** 2.0  
**Last Updated:** January 2026  
**Platform:** IDE Mode: Any — Simple Mode: Any — Adaptive Mode: Windows  

