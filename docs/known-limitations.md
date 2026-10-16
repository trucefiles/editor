# Known limitations

Accepted behavior that is not planned to change.

1. **A note named like a conflict copy shows as a conflict.** A note whose
   file name looks like a Syncthing conflict copy (for example
   `todo.sync-conflict-20261003-134809-ABCDEFG.md`) is listed as a conflict
   of `todo.md`, not as a note of its own.
2. **A note renamed or moved outside the app loses its marks.** Its pin,
   color and "Done" section choice, and the view it was last shown in,
   belong to its old path. They are cleaned up later: marks at this
   device's next change to any mark in that folder, views each time the app
   comes into use.
3. **Backups of a folder that was removed and added again stay hidden.**
   The folder gets a new identity in the app, so the Backups screen no
   longer lists its earlier backups. They are deleted after 7 days, like
   every backup.
4. **A conflict copy can bring back a deleted subfolder.** If a note's
   subfolder is deleted on another device while the note has unsaved edits
   here, the edits are kept as a conflict copy in that subfolder, which
   recreates it, so the edits stay visible.
5. **A new note can show an old mark.** Deleting a note drops only this
   device's mark for it. If a note is later created at the same path, it
   shows another device's older pin, color or "Done" section choice until
   that device changes a mark in the folder.
6. **An unmounted drive that leaves an empty folder behind looks emptied.**
   If a note folder is the mount point of a drive and the drive is not
   mounted, the folder is still there but empty, so its notes look deleted
   instead of the folder unreachable.
7. **A drive that stops responding is not detected.** A folder whose file
   system hangs instead of failing (e.g. a network share that is gone) is
   not marked unreachable; what reads it waits.
8. **Edits left in a folder that can't be reached wait for the next start.**
   Closing a note while its folder can't be reached keeps the edits on this
   device; they go into the file the next time the app starts.
9. **A folder that is gone for good blocks the app briefly at each start.**
   The app tries to reach it for a few seconds before marking it
   unreachable; removing the folder from the app ends this.
