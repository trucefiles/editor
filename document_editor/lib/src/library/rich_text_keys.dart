import 'package:super_editor/super_editor.dart';

/// The library's key actions that format, indent or break lines by its
/// own rich text rules, which know no Markdown: each mode edits in its
/// own way instead.
final richTextKeys = <SuperEditorKeyboardAction>{
  cmdBToToggleBold,
  cmdIToToggleItalics,
  backspaceToUnIndentListItem,
  backspaceToUnIndentParagraph,
  backspaceToUnIndentTask,
  backspaceToConvertTaskToParagraph,
  backspaceToClearParagraphBlockType,
  tabToIndentTask,
  shiftTabToUnIndentTask,
  tabToIndentParagraph,
  shiftTabToUnIndentParagraph,
  tabToIndentListItem,
  shiftTabToUnIndentListItem,
  enterToUnIndentParagraph,
  shiftEnterToInsertNewlineInBlock,
};
