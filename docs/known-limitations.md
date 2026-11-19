# Known limitations

Accepted behavior that is not planned to change, grouped by topic.

## Documents

- **A document named like a conflict copy shows as a conflict.** A document
  whose file name looks like a Syncthing conflict copy (for example
  `todo.sync-conflict-20261003-134809-ABCDEFG.md`) is listed as a conflict
  of `todo.md`, not as a document of its own.
- **A conflict copy can bring back a deleted subfolder.** If a subfolder is
  deleted on another device while one of its documents has unsaved edits
  here, the edits are kept as a conflict copy there, which makes the
  subfolder again, so nothing is lost.
- **A moved or renamed document can come back.** Sync tools see a move or
  rename as a delete and a new file. If another device edits the document
  before it learns of the change, the document shows up again in its old
  place.
- **Undo stops at a change from the folder.** Undo takes back your own edits
  of this session. Older versions are in the document's Backups.
- **Empty lines and trailing spaces are not saved.** Markdown has no way to
  store them, so they are gone once the document is saved.
- **A document renamed or moved in another app loses its color and
  settings.** Rename or move it in Truce to keep them.

## Images in documents

- **Removed images stay until you clean up.** An image you delete from a
  document stays in the folder until you use "Remove unused images" in the
  folder's settings.
- **Images from outside a folder don't show.** A document shows an image
  only if the image file is inside the document's folder. An image pasted
  from another folder doesn't show either: add it again with the Image
  button.
- **Restoring a document can make the image folder again.** Its removed
  images come back from their backups, which can make `document-images`
  again if you deleted it.

## Calendars

- **On Linux, alerts ring only while Truce runs.** Turn on "Start at login"
  and "Keep running in tray" so it keeps running when you close the window.
- **Alerts from other devices can take a while to arrive.** In the
  background Truce checks every 15 minutes, and on Android with Truce
  closed about every 2 hours. Some phone makers stop these checks; new
  alerts then wait until you open Truce.
- **Dismissing an alert on one device doesn't dismiss it on others.**
- **An event or task another app removed can come back.** Some apps remove
  it instead of marking it deleted; when their file meets a Truce device's
  copy, it comes back.
- **Time zones named the Windows way read as local time.** Events from
  Outlook or Exchange in another zone can show hours off.
- **Events without an ID show only once imported.** A few apps leave out an
  event's `UID`. Import the file into a calendar to give each one an ID.
- **On Android, an .ics file may not show in the file picker** if another
  app saved it under another file type.

## Unreachable folders

- **Edits in an unreachable folder wait for the next start.** Truce keeps
  them on this device and writes them once the folder is back.
- **A subfolder that can't be read hides its documents.** They are not
  treated as deleted; they show again once it can be read.
- **A drive that is not plugged in can make its folder look empty.** Its
  documents then look deleted instead of the folder looking unreachable.
