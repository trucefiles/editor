# Features in pictures

Screenshots of Truce's main screens and of each new feature, newest
first. They show sample documents only.

## Home, cards and wide windows

Home now has two parts: **Pinned** (every pinned file) and **Recently
edited**. Settings sets how many recently edited files show and, if you
like, how old they can be. A **Clear** chip drops all picks in its row.
A card's footer starts with its type's icon; a long place is cut in the
middle, so the folder and the last subfolder stay readable, and the
whole place shows when you hover over it. Long press a card, or right
click it with a mouse, to open, pin or color it. Settings and forms
stay in one readable column on wide windows, and Esc closes any page or
form.

<img src="screenshots/home/home_desktop.png" width="600" alt="Home: Pinned on top, then Recently edited, each card's footer starting with its type icon">
<img src="screenshots/home/card_menu_desktop.png" width="600" alt="A right click on a card: Open, Pin, Color with its colors, and where the other actions are">
<img src="screenshots/home/card_sheet_touch.png" width="300" alt="A long press on a card on a phone: its title and place, Open, Pin, colors">
<img src="screenshots/settings/settings_desktop.png" width="600" alt="Settings on a wide window, in one centered column">

## Filters, folder order and type icons

Pick as many folder and type chips as you like; tap one again to drop
it, or **Clear** to drop them all. Each file shows its type's icon. In **Manage folders**, drag a folder
by its handle to change its place; the chips and All files follow that
order.

<img src="screenshots/home/home_filters_desktop.png" width="600" alt="Home showing only Markdown files, its chip picked, a Clear chip before it">
<img src="screenshots/folders/folders_order_desktop.png" width="600" alt="Manage folders: each folder with a drag handle">

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
a day or a schedule, the one you picked last. Tap a free time to add an
event there, a day in the month for an all-day event, or drag over a few
hours; **+** adds one too. Drag an event to move it, or its edge to make
it longer (for an event that repeats, that moves just this one). Tap an
event to edit or delete it, just this time or every time. An event can
have its own color; otherwise it shows in its calendar's color (the
file's color, else its folder's). A health calendar shows in the same
views: **+** lists its kinds of entry (medication, symptom, measure,
note, period), each with its own form and color. Once a period is
written, the month shades period days and fertile days, stripes the
likely next period, and the line below tells the day of the cycle.
Today always has a blue outline. With a mouse, Shift and the wheel page
to the next or previous month, week or day. Once your
folders hold a calendar, the **Calendar** tab shows the events of all
of them in the same views. Tap an event there to see it, then open its
calendar or edit it on its page; **+** picks a calendar and starts
adding there. When two devices changed
the same calendar, the compare view offers **Merge both**: events merge
one by one, and where both changed the same event, the newer change is
kept.

<img src="screenshots/calendar/calendar_month_desktop.png" width="600" alt="A calendar's page in the month view">
<img src="screenshots/calendar/calendar_week_desktop.png" width="600" alt="The same calendar in the week view, events by hour">
<img src="screenshots/calendar/calendar_schedule_touch.png" width="300" alt="The schedule view on a phone: events listed by date">
<img src="screenshots/calendar/calendar_health_touch.png" width="300" alt="A health calendar on a phone: period days shaded, the likely next period striped, today outlined, the cycle line below">
<img src="screenshots/calendar/calendar_tab_desktop.png" width="600" alt="The Calendar tab: two calendars as chips above one month">
<img src="screenshots/calendar/calendar_tab_sheet_touch.png" width="300" alt="An event tapped in the Calendar tab: its details with Open calendar and Edit">

## Home, All and search

Home shows your pinned files, then your recently edited documents from
every folder. The view button at the top switches to **All files**:
every document, newest first or by name (by name, under each
subfolder), as cards or a list. When Recently edited hides some,
**Show all** below it does the same. Search looks through every folder,
by title, text, file and folder names.

<img src="screenshots/home/view_menu_desktop.png" width="600" alt="The view menu: Home or All files, the order and cards or list">
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
the buttons at the top or Ctrl+Z and Ctrl+Y. When there is nothing more to
undo, one more Undo says why and leads to the document's backups. The
menu's **Backups** lists only this document's backups: open one to compare
it, then restore it (Undo takes that back too) or delete it.

<img src="screenshots/backups/document_backups_desktop.png" width="600" alt="The backups of one document, newest first">
<img src="screenshots/backups/undo_end_notice_desktop.png" width="600" alt="A note at the bottom: nothing more to undo since you opened the file, with a Backups button">

## Editing a document

The same document in each mode: **Visual edit** (lists, checkboxes, styles,
with the format bar), **Markdown edit** (every character, highlighted once
typing pauses) and **Read**, on the desktop and on a phone.

<img src="screenshots/editor/editor_visual_desktop.png" width="600" alt="Visual edit on the desktop, with the format bar">
<img src="screenshots/editor/editor_visual_touch.png" width="280" alt="Visual edit on a phone">

<img src="screenshots/editor/editor_markdown_desktop.png" width="600" alt="Markdown edit, showing the Markdown marks">
<img src="screenshots/editor/editor_read_desktop.png" width="600" alt="Read, the document rendered">
