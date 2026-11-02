/// The folders the user adds on this device: the folder list owner with
/// every plugin's state, the open folders and their services, and how
/// changes in them are followed.
///
/// Pure Dart, no UI; knows no plugin and no file type, which the app
/// wires in.
library;

export 'src/folder.dart';
export 'src/folder_color_names.dart';
export 'src/folder_error.dart';
export 'src/folder_list_contract.dart';
export 'src/folder_list_owner.dart';
export 'src/folder_list_store.dart';
export 'src/folder_plugins.dart';
export 'src/folder_state/following_changes.dart';
export 'src/open_folders/app_writes.dart';
export 'src/open_folders/folder_following.dart';
export 'src/open_folders/folder_services.dart';
export 'src/open_folders/open_folders.dart';
export 'src/refresh/refresh_settings.dart';
