#include "session_end.h"

struct _SessionEnd {
  // Not owned: it outlives this.
  GtkApplication* application;
  FlMethodChannel* channel;
  GCancellable* cancellable;
  gulong query_end_handler;
  // The logout inhibit while Dart keeps the edits; 0 when none is held.
  guint inhibit_cookie;
};

static void release(SessionEnd* self) {
  if (self->inhibit_cookie != 0) {
    gtk_application_uninhibit(self->application, self->inhibit_cookie);
    self->inhibit_cookie = 0;
  }
}

// Dart answered, or failed to: either way the end goes on.
static void query_end_answered_cb(GObject* object,
                                  GAsyncResult* result,
                                  gpointer user_data) {
  g_autoptr(GError) error = nullptr;
  g_autoptr(FlMethodResponse) response = fl_method_channel_invoke_method_finish(
      FL_METHOD_CHANNEL(object), result, &error);
  // Freed meanwhile: nothing left to release.
  if (g_error_matches(error, G_IO_ERROR, G_IO_ERROR_CANCELLED)) {
    return;
  }
  if (error != nullptr) {
    g_warning("Session end not answered: %s", error->message);
  }
  release(static_cast<SessionEnd*>(user_data));
}

static void query_end_cb(GtkApplication* application, gpointer user_data) {
  SessionEnd* self = static_cast<SessionEnd*>(user_data);
  // Asked again while Dart is still keeping the edits.
  if (self->inhibit_cookie != 0) {
    return;
  }
  // No window: it also holds the end while the app is in the tray.
  self->inhibit_cookie = gtk_application_inhibit(
      application, nullptr, GTK_APPLICATION_INHIBIT_LOGOUT,
      "Saving your edits");
  fl_method_channel_invoke_method(self->channel, "queryEnd", nullptr,
                                  self->cancellable, query_end_answered_cb,
                                  self);
}

SessionEnd* session_end_new(GtkApplication* application,
                            FlBinaryMessenger* messenger) {
  SessionEnd* self = g_new0(SessionEnd, 1);
  self->application = application;
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->channel = fl_method_channel_new(messenger,
                                        "io.github.trucefiles.editor/session",
                                        FL_METHOD_CODEC(codec));
  self->cancellable = g_cancellable_new();
  self->query_end_handler = g_signal_connect(
      application, "query-end", G_CALLBACK(query_end_cb), self);
  return self;
}

void session_end_free(SessionEnd* self) {
  if (self == nullptr) {
    return;
  }
  g_signal_handler_disconnect(self->application, self->query_end_handler);
  g_cancellable_cancel(self->cancellable);
  release(self);
  g_clear_object(&self->cancellable);
  g_clear_object(&self->channel);
  g_free(self);
}
