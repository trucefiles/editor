# Markdown in Truce

Notes are plain Markdown files. Truce reads them as standard Markdown
([CommonMark](https://commonmark.org) with GitHub's task lists and
tables), so any other Markdown app shows them the same way. When you
edit, Truce changes only the blocks you touched and keeps their style
where it can. Everything else in the file stays exactly as it was.

## How notes show

- **All standard Markdown.** Paragraphs, headings, quotes, lists, code
  blocks, tables, lines, HTML and link definitions all show as the
  standard says, nested as deep as you like (for example a quote inside a
  list item inside a quote).
- **Three views.**
  - **Visual edit** shows each block as it looks (quote bar, list marker,
    indent), without Markdown symbols. What you type there is text: a
    typed `*` or `- ` stays a `*` or `- ` (saved escaped, e.g. `\*`). Use
    the toolbar or keys (Ctrl+B, Tab, ...) for styles and lists.
    Tables and other raw blocks show their Markdown when you tap them.
  - **Markdown edit** shows every character of the file.
  - **Read** shows the note the way any Markdown viewer draws it.
- **Front matter** (lines between two `---` lines at the very top) shows
  dimmed while editing and is hidden in Read.
- **Tables** are drawn as tables. Tap one to edit its Markdown lines.
- **Images** show inside the note, from the web or from the note's
  folder.

## Editing

- **Enter** starts a new paragraph, saved with a blank line between
  them. **Shift+Enter** (or the toolbar's line break button) starts a new
  line in the same paragraph or item.
- **Enter** in a list item starts the next item. In an empty item it
  moves the item one level out, or out of the list.
  - When a line leaves a list or quote and would run into the text above,
    Truce adds a blank line between them.
- **Paste** turns each pasted line into its own item in a list, or its
  own paragraph elsewhere, like pressing Enter.
- **List buttons** turn lines into a list, or change its kind. Pressed
  again where the lines already have that kind (or a checkbox), they make
  the lines text again.
- **Numbering.** Numbered items count on from the list's first number. A
  new numbered sublist starts at 1.
- **Empty checklist items** are saved as `- [ ] ` with a space at the
  end, so other apps see them as checklist items too. This is the only
  place Truce saves a trailing space.
- **New notes end with a line break**, as most tools expect. Files that
  already exist keep how they end.
- **Lines that join the text above.** A line of text right below a list
  item or quote belongs to it, even without indent or `>`. That's the
  standard's rule.

## Where Truce differs

- **A box at the line end is a checklist item.** `- [ ]` with nothing
  after it shows as an empty checklist item. The standard's own tool
  needs a space after the box, so Truce saves empty items that way.
