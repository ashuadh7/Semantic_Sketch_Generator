// ── NodeState ─────────────────────────────────────────────────────────────────

final int SHAPE_CIRCLE  = 0;
final int SHAPE_RECT    = 1;
final int SHAPE_DIAMOND = 2;


class NodeState {
  String  label;
  float   r;
  float   ang;

  color   fillCol       = color(245);
  int     alpha         = 255;
  int     shapeType     = SHAPE_CIRCLE;
  float   labelAng      = 0;           // radians, 0=top; only used when img != null
  color   orbitCol    = color(180);
  boolean orbitDashed = true;

  PImage  img           = null;
  boolean cropToShape   = true;
  PImage  imgMasked     = null;
  int     imgCacheSize  = -1;
  int     imgCacheShape = -1;

  int         subType      = SLOT_PLAIN;
  float       subOrbitR    = 80.0;
  float       subScale     = 1.0;   // fixed at promote() — never recomputed from r
  float       subAngOffset = 0.0;   // manual rotation offset for satellite cluster (radians)
  NodeState[] children     = null;

  NodeState(String label, float r, float ang) {
    this.label = label; this.r = r; this.ang = ang;
  }

  boolean isHub()          { return subType != SLOT_PLAIN && children != null; }
  int     numSatellites()  { return children == null ? 0 : children.length - 1; }

  // ── Promote to hub ─────────────────────────────────────────────────────────
  void promote(int type, int n) {
    subType  = type;
    subScale = 1.75 * r / subOrbitR;   // orbit starts at 1.75× hub radius, well outside edge
    children = new NodeState[n + 1];
    children[0] = new NodeState(label, r * 0.6, 0);
    children[0].fillCol   = fillCol;
    children[0].shapeType = shapeType;
    for (int i = 0; i < n; i++) {
      float a = angleFor(type, i, n);
      float rSat = max(8, min(r * 0.45, (TWO_PI * subOrbitR / n) * 0.36));
      children[i+1] = new NodeState("Node " + (char)('A'+i%26), rSat, a);
    }
  }

  void demote() { subType = SLOT_PLAIN; children = null; }

  // ── Add / remove satellites ────────────────────────────────────────────────
  void addSatellite() {
    if (children == null) return;
    int oldN = children.length - 1;
    int newN = oldN + 1;
    NodeState[] next = new NodeState[newN + 1];
    next[0] = children[0];
    for (int i = 0; i < oldN; i++) next[i+1] = children[i+1];
    float rSat = max(8, min(children[0].r * 0.7, (TWO_PI * subOrbitR / newN) * 0.36));
    next[newN] = new NodeState("Node " + (char)('A'+(newN-1)%26), rSat, 0);
    children = next;
    recomputeAngles();
  }

  void removeSatellite(int i) {
    if (children == null || i < 1 || i >= children.length) return;
    if (children.length <= 2) { demote(); return; }
    NodeState[] next = new NodeState[children.length - 1];
    next[0] = children[0];
    int k = 1;
    for (int j = 1; j < children.length; j++) if (j != i) next[k++] = children[j];
    children = next;
    recomputeAngles();
  }

  void recomputeAngles() {
    if (children == null) return;
    int n = children.length - 1;
    for (int i = 0; i < n; i++)
      children[i+1].ang = angleFor(subType, i, n);
  }

  float angleFor(int type, int i, int n) {
    return type == SLOT_SPOKE
      ? radians(180 + i * (360.0 / n))
      : radians(i * (360.0 / n));
  }

  // ── Proportional scale (Shift+[/]) ────────────────────────────────────────
  // Scales orbit and all children's r recursively, preserving ratios.
  void scaleProportional(float factor) {
    if (!isHub()) return;
    subOrbitR *= factor;
    // children[0] holds the gap radius used for arrows — scale it proportionally
    children[0].r = max(6, children[0].r * factor);
    children[0].invalidateCache();
    for (int i = 1; i < children.length; i++) {
      children[i].r = max(6, children[i].r * factor);
      children[i].invalidateCache();
      if (children[i].isHub()) children[i].scaleProportional(factor);
    }
  }

  // ── Cache management ───────────────────────────────────────────────────────
  void invalidateCache() { imgMasked=null; imgCacheSize=-1; imgCacheShape=-1; }

  void rebuildMask(int diameter) {
    if (img==null||!cropToShape) { imgMasked=null; return; }
    if (imgCacheSize==diameter&&imgCacheShape==shapeType&&imgMasked!=null) return;
    imgCacheSize=diameter; imgCacheShape=shapeType;

    PGraphics imgG=createGraphics(diameter,diameter,JAVA2D);
    imgG.beginDraw(); imgG.clear();
    imgG.image(img, 0, 0, diameter, diameter);
    imgG.endDraw();

    PGraphics mask=createGraphics(diameter,diameter,JAVA2D);
    mask.beginDraw(); mask.background(0); mask.noStroke(); mask.fill(255);
    int cx=diameter/2, cy=diameter/2;
    if      (shapeType==SHAPE_CIRCLE)  mask.ellipse(cx,cy,diameter,diameter);
    else if (shapeType==SHAPE_RECT)    mask.rect(0,0,diameter,diameter,(int)(cx*0.3));
    else { mask.beginShape();
           mask.vertex(cx,0); mask.vertex(diameter,cy);
           mask.vertex(cx,diameter); mask.vertex(0,cy);
           mask.endShape(CLOSE); }
    mask.endDraw();
    imgG.mask(mask);
    imgMasked = imgG;
  }
}

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
NodeState pendingImageNode = null;
NodeState pendingImportNode = null;

void imageSelected(File f) {
  if (f==null||pendingImageNode==null) return;
  PImage loaded=loadImage(f.getAbsolutePath());
  if (loaded!=null) { pendingImageNode.img=loaded; pendingImageNode.alpha=0; pendingImageNode.invalidateCache(); }
  pendingImageNode=null;
}

void stateFileSelected(File f)  { loadStateFromFile(f); }
void importNodeSelected(File f) { importNodeFromFile(f); }

// ── Hub orbit adjustment (top-level frameworks) ───────────────────────────────
void adjustHubOrbit(int frameId, float delta) {
  switch(frameId) {
    case 0: spokeOrbitR    = max(60, spokeOrbitR    + delta); break;
    case 1: crossOrbitR    = max(60, crossOrbitR    + delta); break;
    case 2: twoOuterOrbitR = max(60, twoOuterOrbitR + delta); break;
  }
}

// ── Init ──────────────────────────────────────────────────────────────────────
void initAllStates() { initSpokeState(); initCrossState(); initTwoState(); }

void initSpokeState() {
  int needed=nSpoke+1;
  if (spokeState!=null&&spokeState.length==needed) return;
  spokeState=new NodeState[needed];
  spokeState[0]=new NodeState("center",50,0);
  for (int i=0;i<nSpoke;i++) {
    float ang=radians(180+i*(360.0/nSpoke));
    spokeState[i+1]=new NodeState("Node "+(char)('A'+i%26),55,ang);
  }
}

void initCrossState() {
  int needed=nCross+1;
  if (crossState!=null&&crossState.length==needed) return;
  crossState=new NodeState[needed];
  crossState[0]=new NodeState("center",60,0);
  for (int i=0;i<nCross;i++) {
    float ang=radians(i*(360.0/nCross));
    float rSat=min(58,(TWO_PI*185/nCross)*0.36);
    crossState[i+1]=new NodeState("Node "+(char)('A'+i%26),rSat,ang);
  }
}

void initTwoState() {
  if (twoState != null && twoState.length >= 1) return;
  twoState    = new NodeState[1];
  twoState[0] = new NodeState("center", 52, 0);
}
