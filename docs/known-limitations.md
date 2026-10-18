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

- **A moved note can come back.** Sync tools see a move between folders
  as a delete and a new file. If another device edits the note before it
  learns of the move, the edited note shows up again in its old place,
  next to the moved one.
- **Backups stay with a note's old place.** After a move, the Backups
  screen lists the note's earlier backups under its old folder and name.

## Colors, pins and views

- **A note renamed or moved outside the app loses its color and
  settings.** Its color (synced) and its pin, checked items choice and
  last view (this device only) belong to its old path. Moving it in the
  app keeps them. They are cleaned up
  later: colors at this device's next change to any color in that folder,
  settings each time the app comes into use.
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
