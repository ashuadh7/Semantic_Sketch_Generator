// ── History.pde ───────────────────────────────────────────────────────────────
// Global undo/redo snapshot stack (Ctrl+Z / Ctrl+Y).
// Each snapshot is a full app-state JSONObject built by buildStateJSON().
// Stack capped at UNDO_MAX entries; oldest entry dropped when full.
// ─────────────────────────────────────────────────────────────────────────────

final int UNDO_MAX = 50;

ArrayList<JSONObject> undoStack = new ArrayList<JSONObject>();
ArrayList<JSONObject> redoStack = new ArrayList<JSONObject>();

// Call this BEFORE any mutating action to capture the current state.
void pushUndoSnapshot() {
  redoStack.clear();
  if (undoStack.size() >= UNDO_MAX) undoStack.remove(0);
  undoStack.add(buildStateJSON());
}

// Ctrl+Z — restore previous state.
void undoGlobal() {
  if (undoStack.isEmpty()) { showToast("Nothing to undo."); return; }
  JSONObject current = buildStateJSON();
  if (redoStack.size() >= UNDO_MAX) redoStack.remove(0);
  redoStack.add(current);
  restoreStateFromJSON(undoStack.remove(undoStack.size() - 1));
  showToast("Undo  (" + undoStack.size() + " left)");
}

// Ctrl+Y — restore next state.
void redoGlobal() {
  if (redoStack.isEmpty()) { showToast("Nothing to redo."); return; }
  JSONObject current = buildStateJSON();
  if (undoStack.size() >= UNDO_MAX) undoStack.remove(0);
  undoStack.add(current);
  restoreStateFromJSON(redoStack.remove(redoStack.size() - 1));
  showToast("Redo  (" + redoStack.size() + " left)");
}
