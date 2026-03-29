// ── NodeState ─────────────────────────────────────────────────────────────────
// Data model for a single diagram node: appearance, children, and image cache.
// ─────────────────────────────────────────────────────────────────────────────

// ── Shape type constants ──────────────────────────────────────────────────────
final int SHAPE_CIRCLE  = 0;
final int SHAPE_RECT    = 1;
final int SHAPE_DIAMOND = 2;

// ── Sub-diagram slot type constants ──────────────────────────────────────────
final int SLOT_PLAIN = 0;
final int SLOT_CROSS = 1;
final int SLOT_SPOKE = 2;

class NodeState {
  String  label;
  float   r;
  float   ang;

  color   fillCol       = color(245);
  int     alpha         = 255;
  int     shapeType     = SHAPE_CIRCLE;
  float   labelAng      = 0;           // radians, 0=top; only used when img != null
  int     labelSize     = 12;
  String  subLabel      = "";
  color   orbitCol      = color(180);
  boolean orbitDashed   = true;
  boolean viewCollapsed = false;       // transient View-mode only; never serialised

  PImage  img           = null;
  boolean cropToShape   = true;
  PImage  imgMasked     = null;
  int     imgCacheSize  = -1;
  int     imgCacheShape = -1;

  int         subType      = SLOT_PLAIN;
  float       subOrbitR    = 80.0;
  float       subScale     = 1.0;
  float       subAngOffset = 0.0;
  NodeState[] children     = null;

  NodeState(String label, float r, float ang) {
    this.label = label; this.r = r; this.ang = ang;
  }

  boolean isHub()         { return subType != SLOT_PLAIN && children != null; }
  int     numSatellites() { return children == null ? 0 : children.length - 1; }

  // ── Promote to hub ─────────────────────────────────────────────────────────
  void promote(int type, int n) {
    subType  = type;
    subScale = 1.75 * r / subOrbitR;
    children = new NodeState[n + 1];
    children[0] = new NodeState(label, r * 0.6, 0);
    children[0].fillCol   = fillCol;
    children[0].shapeType = shapeType;
    for (int i = 0; i < n; i++) {
      float a    = angleFor(type, i, n);
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
  void scaleProportional(float factor) {
    if (!isHub()) return;
    subOrbitR *= factor;
    children[0].r = max(6, children[0].r * factor);
    children[0].invalidateCache();
    for (int i = 1; i < children.length; i++) {
      children[i].r = max(6, children[i].r * factor);
      children[i].invalidateCache();
      if (children[i].isHub()) children[i].scaleProportional(factor);
    }
  }

  // ── Image mask cache ───────────────────────────────────────────────────────
  void invalidateCache() { imgMasked=null; imgCacheSize=-1; imgCacheShape=-1; }

  void rebuildMask(int diameter) {
    if (img==null || !cropToShape) { imgMasked=null; return; }
    if (imgCacheShape==shapeType && imgMasked!=null) return;
    imgCacheSize=diameter; imgCacheShape=shapeType;

    // Bake at the image's native resolution so zooming in View mode stays sharp
    int res = max(img.width, img.height);
    int cx=res/2, cy=res/2;

    PGraphics imgG = createGraphics(res, res, JAVA2D);
    imgG.beginDraw(); imgG.clear();
    // Center-crop: scale to cover the square while preserving aspect ratio
    float asp = (float)img.width / img.height;
    float dw, dh;
    if (asp >= 1.0) { dh = res; dw = res * asp; }
    else            { dw = res; dh = res / asp; }
    imgG.image(img, (res-dw)*0.5, (res-dh)*0.5, dw, dh);
    imgG.endDraw();

    PGraphics mask = createGraphics(res, res, JAVA2D);
    mask.beginDraw(); mask.background(0); mask.noStroke(); mask.fill(255);
    if      (shapeType==SHAPE_CIRCLE)  mask.ellipse(cx, cy, res, res);
    else if (shapeType==SHAPE_RECT)    mask.rect(0, 0, res, res, (int)(cx*0.3));
    else {
      mask.beginShape();
      mask.vertex(cx,0); mask.vertex(res,cy);
      mask.vertex(cx,res); mask.vertex(0,cy);
      mask.endShape(CLOSE);
    }
    mask.endDraw();
    imgG.mask(mask);
    imgMasked = imgG;
  }
}
