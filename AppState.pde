// ── AppState ──────────────────────────────────────────────────────────────────
// Global application and session state: diagram configuration, node arrays,
// initialisation helpers, orbit adjustments, and file-dialog callbacks.
// ─────────────────────────────────────────────────────────────────────────────

// ── Diagram configuration ─────────────────────────────────────────────────────
int nSpoke=4, nCross=5, nInner=0, nOuter=4;
int appMode=0, activeFrame=2;

// ── Top-level orbit radii ─────────────────────────────────────────────────────
float spokeOrbitR    = 190;
float crossOrbitR    = 185;
float twoInnerOrbitR = 110;
float twoOuterOrbitR = 280;

// ── Node arrays ───────────────────────────────────────────────────────────────
NodeState[] spokeState;
NodeState[] crossState;
NodeState[] twoState;

// ── Pending file operations ───────────────────────────────────────────────────
NodeState pendingImageNode  = null;
NodeState pendingImportNode = null;

// ── State accessors ───────────────────────────────────────────────────────────
NodeState[] activeStates() {
  switch (activeFrame) {
    case 0: return spokeState;
    case 1: return crossState;
    case 2: return twoState;
  }
  return null;
}

void setActiveStates(NodeState[] next) {
  switch (activeFrame) {
    case 0: spokeState = next; break;
    case 1: crossState = next; break;
    case 2: twoState   = next; break;
  }
}

void adjustHubOrbit(int frameId, float delta) {
  switch (frameId) {
    case 0: spokeOrbitR    = max(60, spokeOrbitR    + delta); break;
    case 1: crossOrbitR    = max(60, crossOrbitR    + delta); break;
    case 2: twoOuterOrbitR = max(60, twoOuterOrbitR + delta); break;
  }
}

// ── Initialisation ────────────────────────────────────────────────────────────
void initAllStates() { initSpokeState(); initCrossState(); initTwoState(); }

void initSpokeState() {
  int needed = nSpoke + 1;
  if (spokeState != null && spokeState.length == needed) return;
  spokeState = new NodeState[needed];
  spokeState[0] = new NodeState("center", 50, 0);
  for (int i = 0; i < nSpoke; i++) {
    float ang = radians(180 + i * (360.0/nSpoke));
    spokeState[i+1] = new NodeState("Node " + (char)('A'+i%26), 55, ang);
  }
}

void initCrossState() {
  int needed = nCross + 1;
  if (crossState != null && crossState.length == needed) return;
  crossState = new NodeState[needed];
  crossState[0] = new NodeState("center", 60, 0);
  for (int i = 0; i < nCross; i++) {
    float ang  = radians(i * (360.0/nCross));
    float rSat = min(58, (TWO_PI * 185 / nCross) * 0.36);
    crossState[i+1] = new NodeState("Node " + (char)('A'+i%26), rSat, ang);
  }
}

void initTwoState() {
  if (twoState != null && twoState.length >= 1) return;
  twoState    = new NodeState[1];
  twoState[0] = new NodeState("center", 52, 0);
}

// ── File dialog callbacks ─────────────────────────────────────────────────────
void imageSelected(File f) {
  if (f == null || pendingImageNode == null) return;
  PImage loaded = loadImage(f.getAbsolutePath());
  if (loaded != null) {
    pendingImageNode.img = loaded;
    pendingImageNode.alpha = 0;
    pendingImageNode.invalidateCache();
  }
  pendingImageNode = null;
}

void stateFileSelected(File f)  { loadStateFromFile(f); }
void importNodeSelected(File f) { importNodeFromFile(f); }
