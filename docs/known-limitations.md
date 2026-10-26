# Known limitations

Accepted behavior that is not planned to change, grouped by topic.

## Note names and conflicts

- **A note named like a conflict copy shows as a conflict.** A note whose
  file name looks like a Syncthing conflict copy (for example
  `todo.sync-conflict-20261003-134809-ABCDEFG.md`) is listed as a conflict
  of `todo.md`, not as a note of its own.
- **A conflict copy can bring back a deleted subfolder.** If a note's
  subfolder is deleted on another device while the note has unsaved edits
  here, the edits are kept as a conflict copy in that subfolder, which
  recreates it, so the edits stay visible.

- **A moved or renamed note can come back.** Sync tools see a move or
  rename as a delete and a new file. If another device edits the note
  before it learns of the change, the edited note shows up again in its
  old place, next to the moved one.
- **Backups stay with a note's old place.** After a move or rename, the
  Backups screen lists the note's earlier backups under its old folder
  and name.

## Editing Markdown

- **Edited blocks may change escapes and references.** A block you edit
  is written anew in its own style, so its escapes and character
  references can change (`*` becomes `\*`, `&copy;` becomes `©`); what
  it shows stays the same.
- **What Markdown can't write isn't saved.** An empty paragraph (for
  example one added below a table to type into) and spaces at a line's
  end show while you edit but are not in the file. Pick mine and the
  compare view show the saved text, so they can differ from the screen
  there.
- **Inline HTML moved to a line's start can become text.** When an edit
  puts a tag at the start of a line, where Markdown would read it as the
  start of an HTML block, it is written as text.
- **An HTML block typed open takes in what follows only once read
  again.** Editing an HTML block's raw lines so that it no longer ends
  (for example `<!--` without `-->`) shows the blocks after it as before
  until the document is read again (reopened, or changed elsewhere);
  then they belong to the HTML block, as the standard reads it.
- **Front matter only at the very top.** Lines between `---` lines count
  as front matter only at the start of a document; anywhere else they
  read as the standard reads them (a rule, text, a heading).
- **A check tapped just before a change elsewhere flips back.** A check
  waits about 0.7 s before it counts; a change from another device
  arriving in that time (or the app ending abruptly) loses it, so the
  item shows unchecked again.

## Colors, pins and views

- **A note renamed or moved outside the app loses its color and
  settings.** Its color (synced) and its pin, checked items choice and
  last view (this device only) belong to its old path. Moving or renaming
  it in the app keeps its color everywhere and its settings on this
  device; other devices lose their own settings for it. They are cleaned
  up later: colors at this device's next change to any color in that
  folder, settings once the note has been missing for 7 days.
- **A new note can show an old color.** Deleting a note drops only this
  device's color for it. If a note is later created at the same path, it
  shows another device's older color until that device changes a color in
  the folder.

## Backups

- **Backups of a folder that was removed and added again stay hidden.**
  The folder gets a new identity in the app, so the Backups screen no
  longer lists its earlier backups. They are deleted after 7 days, like
  every backup.

## Unreachable folders

- **A failed action is not redone when the folder comes back.** If a save
  or rescan fails while the app tries to reach a folder again, it is not
  repeated once the folder is back: the next rescan shows the folder
  again, and a note's edits are saved at its next edit or when it closes.
- **Typing stops while the app tries to reach a folder.** The note being
  edited loses the cursor while the "Trying to reach" overlay shows; tap
  into it again afterwards.
- **Edits left in a folder that can't be reached wait for the next start.**
  Closing a note while its folder can't be reached keeps the edits on this
  device; they go into the file the next time the app starts.
- **A folder that is gone for good blocks the app briefly at each start.**
  The app tries to reach it for a few seconds before marking it
  unreachable; removing the folder from the app ends this.
- **A subfolder that can't be read hides its notes.** They are not treated
  as deleted, and the home screen names the subfolder, but they can't be
  shown or opened until it can be read again.
- **An unmounted drive that leaves an empty folder behind looks emptied.**
  If a note folder is the mount point of a drive and the drive is not
  mounted, the folder is still there but empty, so its notes look deleted
  instead of the folder unreachable.
- **A drive that stops responding is not detected.** A folder whose file
  system hangs instead of failing (e.g. a network share that is gone) is
  not marked unreachable; what reads it waits.
- **On Linux, the language sets the 12 or 24 hour clock.** Linux tells
  apps no separate clock setting, so times show as the system language
  writes them.
