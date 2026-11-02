# Features in pictures

Screenshots of Truce's main screens and of each new feature, newest
first. They show sample documents only.

## Filter by file type

Below the folder chips, home and **Show all** have one chip per file
type: Markdown, Plain text and Calendar. Pick one to see only files of
that type; tap it again to see all. It works together with the folder
picked.

<img src="screenshots/home/home_type_filter_desktop.png" width="600" alt="Home showing only Markdown files, the Markdown chip picked">

## Adding folders

**Add folder** first asks how the folder is synced: by Syncthing, or not
at all (a local folder). For Syncthing, pick any folder inside a
Syncthing folder: the app finds the Syncthing folder and shows its
folders, to tick each one to add. Each ticked one becomes a folder of its
own, with a name and a color.

<img src="screenshots/folders/add_folder_plugins_desktop.png" width="600" alt="Add folder: Syncthing or Local folder">
<img src="screenshots/folders/add_folder_tree_touch.png" width="300" alt="The folders of a Syncthing folder, two of them ticked">
<img src="screenshots/folders/add_folder_name_desktop.png" width="600" alt="A new folder's name and color">

## Calendars

Calendars are `.ics` files, the format other calendar apps use. **New
file** offers a calendar or a health calendar, named first. A
calendar's card shows its next events. Its page shows a month, a week,
a day or a schedule, the one you picked last. Tap a free time or day to
add an event there, or drag over a few hours; drag an event to move it,
or its edge to make it longer (for an event that repeats, that moves just
this one). Tap an event to edit or delete it, just this time or every
time. A health calendar keeps period days and other entries, and
estimates the next period. Once your folders hold a calendar, the
**Calendar** tab shows the events of all of them in the same views, each
in its folder's color. When two devices changed
the same calendar, the compare view offers **Merge both**: events merge
one by one, and where both changed the same event, the newer change is
kept.

<img src="screenshots/calendar/calendar_month_desktop.png" width="600" alt="A calendar's page in the month view">
<img src="screenshots/calendar/calendar_week_desktop.png" width="600" alt="The same calendar in the week view, events by hour">
<img src="screenshots/calendar/calendar_schedule_touch.png" width="300" alt="The schedule view on a phone: events listed by date">
<img src="screenshots/calendar/calendar_tab_desktop.png" width="600" alt="The Calendar tab: two calendars as chips above one month">

## Recent, All and search

Home shows your most recent documents from every folder, pinned ones on
top. **Show all** opens every document, newest first or by name (by name,
under each subfolder), as cards or a list. Settings sets how many recent
documents home shows. Search looks through every folder, by title, text,
file and folder names.

<img src="screenshots/home/home_recent_desktop.png" width="600" alt="Home: a pinned document, then the recent ones, and a Show all button">
<img src="screenshots/home/all_by_name_desktop.png" width="600" alt="All documents by name, as cards under each subfolder">
<img src="screenshots/home/all_list_desktop.png" width="600" alt="All documents by name, as a list">
<img src="screenshots/home/search_desktop.png" width="600" alt="Search for lake finds two documents">

## Plain text files

Text files (`.txt`) show next to Markdown documents. A card shows the first
line as the title and the next lines below it. A text file opens in the same
page and is edited as written, with no styling: a `#` is just a character.
Undo, backups, compare and conflict copies work as for Markdown.

<img src="screenshots/plain_text/plain_text_cards_desktop.png" width="600" alt="A text file's card next to a Markdown document's card">
<img src="screenshots/plain_text/plain_text_editor_desktop.png" width="600" alt="A text file open, edited as written">

## Undo, redo and a document's backups

Undo and redo take back and redo your edits while a document is open, with
the buttons at the top or Ctrl+Z and Ctrl+Y. Once undo reaches the start, a
note says why and leads to the document's backups. The menu's **Backups**
lists only this document's backups: open one to compare it, then restore it
(Undo takes that back too) or delete it.

<img src="screenshots/backups/document_backups_desktop.png" width="600" alt="The backups of one document, newest first">
<img src="screenshots/backups/undo_end_notice_desktop.png" width="600" alt="A note at the bottom: this is how the document was when you opened it, with a Backups button">

## Editing a document

The same document in each mode: **Visual edit** (lists, checkboxes, styles,
with the format bar), **Markdown edit** (every character, highlighted once
typing pauses) and **Read**, on the desktop and on a phone.

<img src="screenshots/editor/editor_visual_desktop.png" width="600" alt="Visual edit on the desktop, with the format bar">
<img src="screenshots/editor/editor_visual_touch.png" width="280" alt="Visual edit on a phone">

<img src="screenshots/editor/editor_markdown_desktop.png" width="600" alt="Markdown edit, showing the Markdown marks">
<img src="screenshots/editor/editor_read_desktop.png" width="600" alt="Read, the document rendered">
