# Markdown in Truce

Notes are plain Markdown files. Truce reads them as standard Markdown
([CommonMark](https://commonmark.org) with GitHub's task lists and
tables), so any other Markdown app shows them the same way. It changes
only the lines you edit, byte for byte.

## What follows the standard

- **Lists and nesting.** A list item holds the lines indented under it:
  its subitems and its text, also after a blank line. Checking, moving or
  deleting an item takes them along.
- **Multi-line items.** A line of text right below an item's text belongs
  to that item, even without indent. A blank line, then text at the left
  margin, ends the list.
- **Levels.** An item's level is the number of items it sits under,
  however many spaces it is indented with. A tab counts as four spaces.
  Indenting an item moves it at most one level below the item above.
- **Numbering.** Numbered items count on from the first number of their
  list. The count starts anew after a line of text at the same level, or
  when the delimiter changes (`1.` to `1)`).
- **Quotes.** A line right below a quote's text continues the quote, even
  without `>`.
- **Code blocks and tables.** Fenced code blocks (```` ``` ````) and
  tables stay with the item they are in.

## Where Truce differs

- **One list for mixed bullets.** Markdown starts a new list when the
  bullet character or the list kind changes (`-` to `*`, bullets to
  checkboxes). Truce keeps them as one list, so a mixed checklist keeps
  one "Done" section.
- **No indented code blocks.** Only fenced code blocks show as code.
  Lines indented by four or more spaces stay text or list items.
