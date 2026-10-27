# Known limitations

Accepted behavior that is not planned to change, grouped by topic.

## Document names and conflicts

- **A document named like a conflict copy shows as a conflict.** A document whose
  file name looks like a Syncthing conflict copy (for example
  `todo.sync-conflict-20261003-134809-ABCDEFG.md`) is listed as a conflict
  of `todo.md`, not as a document of its own.
- **A conflict copy can bring back a deleted subfolder.** If a document's
  subfolder is deleted on another device while the document has unsaved edits
  here, the edits are kept as a conflict copy in that subfolder, which
  recreates it, so the edits stay visible.

- **A moved or renamed document can come back.** Sync tools see a move or
  rename as a delete and a new file. If another device edits the document
  before it learns of the change, the edited document shows up again in its
  old place, next to the moved one.
- **Backups stay with a document's old place.** After a move or rename, the
  Backups screen lists the document's earlier backups under its old folder
  and name.

## Editing Markdown

- **An edited paragraph may be saved a bit differently.** When you
  change a paragraph or other block, Truce writes that block again. A few
  special characters can then be saved in another, equivalent way (for
  example `*` as `\*`, or `&copy;` as `©`). The document looks the same.
- **Empty lines and trailing spaces are not saved.** Markdown has no way
  to store an empty paragraph or spaces at the end of a line. You see
  them while editing, but they are gone once saved. That's why "Pick
  mine" and the compare view, which show the saved text, can look
  different from the editor.
- **Links keep working when their definition goes.** If an edit removes
  a link definition (a line like `[site]: https://example.org`), the
  links that used it are saved with their address written out, as
  `[site](https://example.org)`.
- **An HTML tag moved to the start of a line becomes plain text.** At
  the start of a line, a tag would turn everything after it into HTML.
  To keep the document as it was, Truce saves the tag as plain text there.
- **An unfinished HTML block shows its effect only later.** If you edit
  an HTML block so that it no longer ends (for example `<!--` without
  `-->`), the blocks below still look the same at first. Once the document
  is opened again or changed on another device, they become part of the
  HTML block, as Markdown says.
- **Front matter only at the top.** Lines between two `---` lines count
  as front matter only at the very start of a document. Anywhere else they
  are normal Markdown (a line, text or a heading).
- **A checkbox tapped just before a remote change can flip back.** Truce
  waits about 0.7 seconds before it saves a tapped checkbox. If a change
  from another device arrives in that time, or the app closes suddenly,
  the tap is lost and the box shows its old state.

## Colors, pins and views

- **A document renamed or moved outside the app loses its color and
  settings.** Truce remembers a document's color, pin, checked-items choice
  and last view by its file name and folder. If you rename or move the
  document in another app, Truce sees a new document and these are gone.
  - Rename or move it in Truce instead: the color then follows on every
    device, and the other settings follow on this device. Other devices
    lose their own pin and view settings for it.
  - Leftovers are cleaned up later: an old color the next time you change
    a color in that folder on this device, other settings after the document
    has been missing for 7 days.
- **A new document can show an old color.** Deleting a document forgets its
  color only on this device. If you later create a document with the same
  name in the same folder, it may show the color another device still
  remembers, until that device changes a color in the folder.

## Backups

- **Backups of a folder you removed and added again stay hidden.** Truce
  treats the re-added folder as a new one, so the Backups screen doesn't
  list its earlier backups. They are deleted after 7 days, like every
  backup.

## Unreachable folders

- **A failed save or rescan is not retried when the folder comes back.**
  Nothing is lost: the next rescan shows the folder again, and your edits
  are saved at your next edit or when you close the document.
- **Typing stops while Truce tries to reach a folder.** While the "Trying
  to reach" overlay shows, the document loses the cursor. Tap into it again
  afterwards.
- **Edits in an unreachable folder wait for the next start.** If you
  close a document while its folder can't be reached, Truce keeps the edits
  on this device and writes them to the file the next time it starts.
- **A folder that is gone for good slows each start a little.** Truce
  tries to reach it for a few seconds before marking it unreachable.
  Remove the folder from Truce to stop this.
- **A subfolder that can't be read hides its documents.** Truce doesn't treat
  them as deleted, and the home screen names the subfolder, but you can't
  see or open them until it can be read again.
- **A drive that is not plugged in can make its folder look empty.** If a
  document folder is where a drive gets mounted and the drive is not mounted,
  the folder is still there but empty. Its documents then look deleted
  instead of the folder looking unreachable.
- **A drive that stops responding is not noticed.** If a folder's storage
  hangs instead of failing (for example a network share that went away),
  Truce doesn't mark it unreachable; it just waits.
- **On Linux, the language decides 12 or 24 hour time.** Linux has no
  separate clock setting for apps, so times show the way the system
  language writes them.
