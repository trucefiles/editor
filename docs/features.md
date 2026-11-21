# Features in pictures

Screenshots of Truce's main screens and of each new feature, newest
first. They show sample documents only.

## Images as files

Pictures in your folders (JPEG, PNG, GIF, WebP, BMP) now show as cards
with a thumbnail, with an **Images** chip to show only them. Tap one to
see it full size and zoom in. Move, rename, pin, color or delete it as
any file, with Undo. If two devices changed a picture, both show side by
side to keep one, and both are backed up first. Backups show pictures
too. **New file** has **Image**: choose one, or take a photo on a phone;
it is saved when you leave, and Truce tells you where with a **Show**
button. Images stay out of Recently edited unless you turn on **Show
images in Recently edited** in Settings. Search finds them by name.

<img src="screenshots/images-as-files/images_all_files_desktop.png" width="600" alt="All files: cards with pictures of a garden, a lake, a QR code, a beach and mountains, beside two documents">
<img src="screenshots/images-as-files/image_page_desktop.png" width="600" alt="A picture of mountains on its own page, its place above it and the menu open: Pin or color, Backups, Delete file">
<img src="screenshots/images-as-files/image_conflict_desktop.png" width="600" alt="Two versions of a garden picture side by side, each with its date and a Keep this button">
<img src="screenshots/images-as-files/new_image_sources_touch.png" width="280" alt="On a phone, a new image: Choose image or Take photo">
<img src="screenshots/images-as-files/image_saved_hint_touch.png" width="280" alt="Back on Home after adding an image: Saved to Documents, with Show">
<img src="screenshots/images-as-files/images_recent_setting_touch.png" width="280" alt="Settings on a phone with larger text: Show images in Recently edited, off">

## Images in documents

In Visual edit, the **Image** button on the format bar adds a picture on
its own line after the caret: from a file dialog on the desktop, or
"Choose image" and "Take photo" on a phone. Truce keeps a copy in the
folder's `document-images` folder, so it syncs with the document. Tap an
image to see it full screen and zoom in. Settings can take the location
out of photos (on by default) and make large pictures smaller. A
folder's settings can remove the images no document shows any more.

<img src="screenshots/images/image_visual_desktop.png" width="600" alt="Visual edit with a picture of a lake in the document and the Image button on the format bar">
<img src="screenshots/images/image_button_touch.png" width="280" alt="The same document on a phone, the format bar scrolled to the Image button">

<img src="screenshots/images/image_viewer_desktop.png" width="600" alt="The picture full screen, on black, with a close button">
<img src="screenshots/images/image_settings_touch.png" width="280" alt="Settings on a phone with larger text: Remove location from photos, on, and Shrink large images, off">
<img src="screenshots/images/image_cleanup_desktop.png" width="600" alt="A folder's settings with Remove unused images below its name and color">

## Home, cards and wide windows

Home now has two parts: **Pinned** (every pinned file) and **Recently
edited**. Settings sets how many recently edited files show and, if you
like, how old they can be. A **Clear** chip drops all picks in its row.
A card's title starts with its type's icon; a long place is cut in the
middle, so the folder and the last subfolder stay readable, and the
whole place shows when you hover over it. Long press a card, or right
click it with a mouse, to open, pin or color it. Settings and forms
stay in one readable column on wide windows, and Esc closes any page or
form.

<img src="screenshots/home/home_desktop.png" width="600" alt="Home: Pinned on top, then Recently edited, each card's title starting with its type icon">
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
file** offers a calendar or a health calendar; it opens at once, and
its name is typed right in its title, now or any time later. A
calendar's card shows its next events. Its page shows a month, a week,
a day or a schedule, the one you picked last for it. Tap a day's number
or header to open that day, or the title above to pick a date: a day,
or a month in the month and schedule views. Tap a free time to add an
event or a task there, a day in the month for an all-day one, or drag
over a few hours; **+** adds one too, and asks which. Drag an event to move it, or its edge to make
it longer (for an event that repeats, that moves just this one). Tap an
event to edit or delete it, just this time or every time. An event can
have its own color, also as a dot when you tap it; otherwise it shows
in its calendar's color (the file's color, else its folder's). Start
and end can each have their own time zone, e.g. for a flight: tap the
zone under a time to pick one.
An event from another zone also shows its own times when you tap it.
Links in an event's place and notes open with a tap, and a tap on the
place opens it in your maps app.
Tasks live in the same calendar, beside its events, as other calendar
apps keep them. A task can have a due date, maybe a time, a repeat and
an alert, or no date at all. It shows on its due day with a box to check
it off; a task due at a time shows as the half hour before it. The
**Tasks** view lists them all: overdue, today, later and with no date,
and below them, folded, those done in the last 30 days. For a task that
repeats, each date is checked on its own, and the list shows one date:
the oldest still open from the last 30 days, else the next. **Import from file** in a calendar's
menu brings in the events and tasks of another `.ics` file, e.g. an invite: new
ones are added, ones the calendar has already take the file's version,
and one Undo takes it all back. A health calendar shows in the same
views: **+** lists its kinds of entry (medication, symptom, measure,
note, period), each with its own form and color. Once a period is
written, the month shades period days and fertile days, shades the
likely next period lighter with faint stripes, and the line below tells
the day of the cycle.
Today always has a blue outline. With a mouse, Shift and the wheel page
to the next or previous month, week or day. Once your
folders hold a calendar, the **Calendars** tab shows the events and
tasks of all of them in the same views, the Tasks view too, in the view
picked last there. A chip turns a calendar on or off;
a long press or right click on it hides the calendar from the tab, and
**Hidden** brings it back. Tap an event or a task there to see it and
its calendar, then open the calendar or edit it on its page. To add,
change or check off, open one
calendar with the calendar button; a tap on a free day in the tab
reminds you. Pinch or Ctrl and + or - zoom the tab and its event
details, as in a document. When two devices changed
the same calendar, the compare view offers **Merge both**: events and
tasks merge one by one, and where both changed the same one, the newer
change is kept.
Alerts ring for the calendars shown in the Calendars tab, whoever set
them. On Android they ring even with the app closed, as a notification
or, if you pick **Alarm** in Settings, full screen until you dismiss or
snooze them. On Linux they ring while the app runs, in a window or the
tray; **Start at login** with **Keep running in tray** keeps it running. An alert that came
while nothing could ring it shows once, quietly, while its event lasts.
Tap an alert to open its event or task.

<img src="screenshots/calendar/calendar_month_desktop.png" width="600" alt="A calendar's page in the month view">
<img src="screenshots/calendar/calendar_week_desktop.png" width="600" alt="The same calendar in the week view, events by hour">
<img src="screenshots/calendar/calendar_schedule_touch.png" width="300" alt="The schedule view on a phone: events listed by date">
<img src="screenshots/calendar/calendar_month_picker_touch.png" width="300" alt="The month view's title tapped on a phone: pick a month, or tap the year to pick another year">
<img src="screenshots/calendar/calendar_health_touch.png" width="300" alt="A health calendar on a phone: period days shaded, the likely next period lighter with faint stripes, today outlined, the cycle line below">
<img src="screenshots/calendar/calendar_tasks_desktop.png" width="600" alt="The Tasks view: overdue, today, later and with no date, each task with its box and when it is due; those done folded below">
<img src="screenshots/calendar/calendar_tasks_month_desktop.png" width="600" alt="The month view with tasks beside events, each with a box to check it off">
<img src="screenshots/calendar/calendar_add_choice_touch.png" width="300" alt="The + button on a phone: add an event or a task">
<img src="screenshots/calendar/calendar_task_form_touch.png" width="300" alt="The task form on a phone: title, due date and time, repeat, alert, color and notes">
<img src="screenshots/calendar/calendar_tasks_touch_large.png" width="300" alt="The Tasks view on a phone with larger text">
<img src="screenshots/calendar/calendar_tab_desktop.png" width="600" alt="The Calendars tab: calendars as chips in one row above one month, faintly striped as it only shows, the open calendar button at the bottom">
<img src="screenshots/calendar/calendar_tab_open_touch.png" width="300" alt="The calendar button on a phone: pick which calendar to open, each with its color">
<img src="screenshots/calendar/calendar_tab_sheet_touch.png" width="300" alt="An event tapped in the Calendars tab: its calendar, then its title, time, place and notes, each on its own line with an icon, with Open calendar and Edit">
<img src="screenshots/calendar/calendar_event_zones_touch.png" width="300" alt="The event form of a flight: start and end each with its own time zone">
<img src="screenshots/calendar/calendar_event_links_touch.png" width="300" alt="An event's sheet: its place and the links in its notes underlined, to open with a tap">
<img src="screenshots/calendar/calendar_alarm_touch.png" width="300" alt="An alert ringing as an alarm on a phone: its title and time, with Dismiss, Snooze 10 min and Open">
<img src="screenshots/calendar/calendar_alert_settings_desktop.png" width="600" alt="Settings on Linux: Start at login, as alerts ring only while the app runs">
<img src="screenshots/calendar/calendar_alert_style_touch.png" width="300" alt="Settings on a phone: calendar alerts ring as a notification or an alarm">

## Home, All and search

Home shows your pinned files, then your recently edited documents from
every folder. The view button at the top switches to **All files**:
every document, newest first or by name (by name, under each
subfolder), as cards or a list. When Recently edited hides some,
**Switch to all files** below it does the same, and Back returns to Home. Search looks through every folder,
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
it, then restore it (Undo takes that back too) or delete it. Deleting a file
keeps a backup of it too. **Restore as new file**, in each backup's menu,
writes it as a new file where and under what name you pick, next to the
file it came from. Backups are kept for up to 7 days, and within the
**Backup space** you pick in Settings (100 MB unless you change it):
when they take more, the file whose backups take the most space gives
up its oldest first; each file keeps its newest, and a deleted file's
backup stays its full 7 days.

<img src="screenshots/backups/document_backups_desktop.png" width="600" alt="The backups of one document, newest first">
<img src="screenshots/backups/undo_end_notice_desktop.png" width="600" alt="A note at the bottom: nothing more to undo since you opened the file, with a Backups button">
<img src="screenshots/backups/backup_space_touch.png" width="300" alt="Settings on a phone: Backup space, from 50 MB to no limit, 100 MB picked, with a note that a smaller limit deletes older backups right away">

## Editing a document

The same document in each mode: **Visual edit** (lists, checkboxes, styles,
with the format bar), **Markdown edit** (every character, highlighted once
typing pauses) and **Read**, on the desktop and on a phone.

<img src="screenshots/editor/editor_visual_desktop.png" width="600" alt="Visual edit on the desktop, with the format bar">
<img src="screenshots/editor/editor_visual_touch.png" width="280" alt="Visual edit on a phone">

<img src="screenshots/editor/editor_markdown_desktop.png" width="600" alt="Markdown edit, showing the Markdown marks">
<img src="screenshots/editor/editor_read_desktop.png" width="600" alt="Read, the document rendered">
