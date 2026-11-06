#ifndef RUNNER_SESSION_END_H_
#define RUNNER_SESSION_END_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

// Holds the desktop session's end while the app keeps its edits: on GTK's
// "query-end" it inhibits the logout and asks Dart ("queryEnd" on the
// "io.github.trucefiles.editor/session" channel, GtkSessionEnd); once Dart
// answers, the end goes on. Needs the application's "register-session" set
// before it starts.
typedef struct _SessionEnd SessionEnd;

SessionEnd* session_end_new(GtkApplication* application,
                            FlBinaryMessenger* messenger);

void session_end_free(SessionEnd* self);

#endif  // RUNNER_SESSION_END_H_
