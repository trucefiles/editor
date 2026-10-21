# Markdown in Truce

Notes are plain Markdown files. Truce reads them as standard Markdown
([CommonMark](https://commonmark.org) with GitHub's task lists and
tables), so any other Markdown app shows them the same way. It changes
only the lines you edit, byte for byte.

## How notes show

- **Every block of the standard.** Paragraphs, headings, quotes, lists,
  code blocks (fenced and indented), tables, rules, HTML and link
  definitions are read as the standard reads them, nested as deep as the
  file nests them: a quote in an item in a quote shows as just that.
- **Edit shows blocks, Markdown shows lines.** Visual edit shows each
  block in its frame (quote bar, item marker, indent) with its marks
  shown only in the block being edited. Markdown edit shows every
  character of every line.
- **Read** shows the note as a standard Markdown renderer draws it.
- **Front matter** (`---` at the very top, a `key:` line, a closing
  `---`) shows dimmed in edit and is left out in Read.
- **Tables** are drawn; a tap edits one as its raw lines.
- **Images** show inline, from the web or from the note's folder.

## Editing

- **Enter** in an item starts the next item; in an empty item it goes
  one level out, or out of the list. Leaving a list or a quote puts a
  blank line above the new line, so text typed there stays out of it.
  **Shift+Enter** (or the toolbar's line break button) adds a line
  inside the same item, written as a `\` line break.
- **Paste** into an item's text makes each further pasted line an item
  of its own, as Enter would; blank lines between them go.
- **Lists and numbering.** Numbered items count on from the first number
  of their list. A new numbered sublist starts at 1.
- **Lazy lines.** A line of text right below an item's or a quote's text
  belongs to it, even without indent or `>`, as the standard says.

## Where Truce differs

- **Lists start more easily.** An empty item (`-`, `1.`) starts a list
  right below text, so a new item shows as one while you type, and a lone
  `-` below text never turns it into a heading.
