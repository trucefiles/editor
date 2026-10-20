# Markdown in Truce

Notes are plain Markdown files. Truce reads them as standard Markdown
([CommonMark](https://commonmark.org) with GitHub's task lists and
tables), so any other Markdown app shows them the same way. It changes
only the lines you edit, byte for byte.

## What follows the standard

- **Lists and nesting.** A list item holds the lines indented at least
  to where its text starts: its subitems, its text, code blocks, quotes
  and tables, also after a blank line. Checking, moving or deleting an
  item takes them along. A line indented less starts a new item or block
  beside it, as on GitHub (`1. a` over `  - b` is two lists).
- **Multi-line items.** A line of text right below an item's text belongs
  to that item, even without indent. A blank line, then text at the left
  margin, ends the list.
- **Levels.** An item's level is the number of items it sits under,
  however many spaces it is indented with. A tab goes on to the next
  multiple of four columns. Indenting an item moves it at most one level
  below the item above.
- **Lists below text.** Right below a line of text, only a list starting
  at 1 starts a numbered list, so `2024. was good` continues the text.
- **Numbering.** Numbered items count on from the first number of their
  list. The count starts anew after a line of text at the same level, or
  when the delimiter changes (`1.` to `1)`).
- **Quotes.** A line right below a quote's text continues the quote, even
  without `>`.
- **Code blocks and tables.** Fenced code blocks (```` ``` ````) and
  tables stay with the item they are in, and end where it ends.
- **Headings.** `# Title` and text over a line of `===` or `---` are
  headings.

## Where Truce differs

- **One list for mixed bullets.** Markdown starts a new list when the
  bullet character or the list kind changes (`-` to `*`, bullets to
  checkboxes). Truce keeps them as one list, so a mixed checklist keeps
  one "Done" section.
- **No HTML blocks.** HTML shows as the text it is.
- **No indented code blocks.** Only fenced code blocks show as code.
  Lines indented by four or more spaces stay text or list items.
- **Lists start more easily.** An empty item (`-`, `1.`) starts a list
  right below text, so a new item shows as one while you type, and a lone
  `-` below text never turns it into a heading. Below an item's text, any
  item starts a subitem, also a numbered one not starting at 1.
- **Quotes hold text only.** Lists and code blocks inside a quote show as
  quoted text. Text over an underline is a heading only on lines of
  their own, not in a quote or an item's first line.
