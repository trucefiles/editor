/// The text editing kit, for file types whose files are text and open
/// on the text editing page. Images and other non-text types never use
/// it.
///
/// Parts, bottom up:
/// - `text`: a file's text in its own byte style ([TextFile]), a text's
///   lines ([splitLines]), the links plain text makes by what it says
///   ([findExtendedAutolinks]), a file
///   version with its text ([Seen]), what lists show of a text
///   ([TextSummary]), and how a type merges two texts ([TextMerge]).
/// - `editor`: what every text type's editor shares: the page's requests
///   and notices ([EditorRequest], [EditorNotice]), the save timing
///   ([SaveClock]) and undo ([EditHistory]), handled alike
///   ([EditorSteps]).
/// - `text_file_owner`: one open text file, kept on the device and in
///   the folder in step with changes elsewhere ([TextFileOwner]).
/// - `files`: a file read as text ([FileText]), text files on top of a
///   folder's bytes ([TextFiles]), and a text type's side of a shown type
///   ([TextFileType]).
/// - `drafts`: putting edits a page kept as a draft of a saved file into
///   it after an app end ([recoverEdits], by the version's fingerprint),
///   and the drafts of older app versions ([OldDraftRecovery]).
/// - `page`: the open file's page model: its session ([TextEditSession])
///   and file effects ([TextEditEffects]).
///
/// Pure Dart, no UI; knows no sync tool and no single file type.
library;

export 'src/drafts/edits_recovery.dart';
export 'src/drafts/fingerprint.dart';
export 'src/drafts/old_draft.dart';
export 'src/drafts/old_draft_recovery.dart';
export 'src/editor/editor_book.dart';
export 'src/editor/editor_contract.dart';
export 'src/editor/editor_steps.dart';
export 'src/editor/history/edit_history.dart';
export 'src/editor/history/text_change.dart';
export 'src/editor/history/text_edit.dart';
export 'src/editor/history/text_step.dart';
export 'src/editor/history/typing.dart';
export 'src/editor/history/undoable_edit.dart';
export 'src/editor/save_clock.dart';
export 'src/files/file_text.dart';
export 'src/files/read_version.dart';
export 'src/files/text_bytes_merge.dart';
export 'src/files/text_file_type.dart';
export 'src/files/text_files.dart';
export 'src/files/text_title.dart';
export 'src/files/version_text.dart';
export 'src/page/editor_part.dart';
export 'src/page/fixed_view_editor_part.dart';
export 'src/page/name_field.dart';
export 'src/page/page_file.dart';
export 'src/page/text_edit_effects.dart';
export 'src/page/text_edit_session.dart';
export 'src/page/text_save_state.dart';
export 'src/text/extended_autolinks.dart';
export 'src/text/lines.dart';
export 'src/text/seen.dart';
export 'src/text/text_file.dart';
export 'src/text/text_merge.dart';
export 'src/text/text_summary.dart';
export 'src/text_file_owner/text_file_owner.dart';
