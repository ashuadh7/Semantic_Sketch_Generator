// ── NodeState ─────────────────────────────────────────────────────────────────

final int SHAPE_CIRCLE  = 0;
final int SHAPE_RECT    = 1;
final int SHAPE_DIAMOND = 2;

class NodeState {
  String  label;
  float   r;
  float   ang;

  // Visual style
  color   fillCol   = color(245);
  int     alpha     = 255;
  int     shapeType = SHAPE_CIRCLE;

  // Orbit style (hub only)
  color   orbitCol    = color(180);
  boolean orbitDashed = true;

  // Image
  PImage  img           = null;
  boolean cropToShape   = true;    // true=crop to shape boundary, false=fit diagonal
  PImage  imgMasked     = null;    // cached masked version
  int     imgCacheSize  = -1;      // diameter at which cache was built
  int     imgCacheShape = -1;      // shapeType at which cache was built

  // Sub-diagram stub
  int subType = SLOT_PLAIN;
  int subN    = 3;

  NodeState(String label, float r, float ang) {
    this.label = label;
    this.r     = r;
    this.ang   = ang;
  }

  // Invalidate cache (call when r or shapeType or cropToShape changes)
  void invalidateCache() {
    imgMasked    = null;
    imgCacheSize  = -1;
    imgCacheShape = -1;
  }

  // Rebuild masked image cache.
  // Crop mode: image fills inscribed circle (diameter = 2r), masked to shape.
  // Fit mode:  no cache needed — drawn inline with diagonal scaling.
  void rebuildMask(int diameter) {
    if (img == null || !cropToShape) { imgMasked = null; return; }
    if (imgCacheSize == diameter && imgCacheShape == shapeType
        && imgMasked != null) return;

    imgCacheSize  = diameter;
    imgCacheShape = shapeType;

    // Step 1: draw image scaled to inscribed circle of the shape
    // Circle/Rect: inscribed circle radius = r (fills diameter x diameter)
    // Diamond:     inscribed circle radius = r/sqrt(2) — circle touching midpoints of sides
    int imgSize;
    if (shapeType == SHAPE_DIAMOND) {
      imgSize = (int)(diameter / sqrt(2.0));
    } else {
      imgSize = diameter;
    }
    int offset = (diameter - imgSize) / 2;

    PGraphics imgG = createGraphics(diameter, diameter, JAVA2D);
    imgG.beginDraw();
    imgG.clear();
    imgG.image(img, offset, offset, imgSize, imgSize);
    imgG.endDraw();

    // Step 2: build mask in shape of the node
    PGraphics mask = createGraphics(diameter, diameter, JAVA2D);
    mask.beginDraw();
    mask.background(0);       // black = transparent
    mask.noStroke();
    mask.fill(255);            // white = opaque
    int cx = diameter / 2;
    int cy = diameter / 2;
    int r2 = diameter / 2;
    if (shapeType == SHAPE_CIRCLE) {
      mask.ellipse(cx, cy, diameter, diameter);
    } else if (shapeType == SHAPE_RECT) {
      int corner = (int)(r2 * 0.3);
      mask.rect(0, 0, diameter, diameter, corner);
    } else { // DIAMOND
      mask.beginShape();
        mask.vertex(cx,    0);
        mask.vertex(diameter, cy);
        mask.vertex(cx,    diameter);
        mask.vertex(0,     cy);
      mask.endShape(CLOSE);
    }
    mask.endDraw();

    // Step 3: apply mask
    imgG.mask(mask);
    imgMasked = imgG;
  }
}

// ── Orbit radii ───────────────────────────────────────────────────────────────
float spokeOrbitR    = 190;
float crossOrbitR    = 185;
float twoInnerOrbitR = 110;
float twoOuterOrbitR = 280;

float[] slotOrbitR;
float[] slotScale;

// ── Node arrays ───────────────────────────────────────────────────────────────
NodeState[] spokeState;
NodeState[] crossState;
NodeState[] twoState;
NodeState[][] slotStates;

// ── Image loading ─────────────────────────────────────────────────────────────
NodeState pendingImageNode = null;

void imageSelected(File f) {
  if (f == null || pendingImageNode == null) return;
  PImage loaded = loadImage(f.getAbsolutePath());
  if (loaded != null) {
    pendingImageNode.img = loaded;
    pendingImageNode.invalidateCache();
  }
  pendingImageNode = null;
}

// ── Hub orbit adjustment ──────────────────────────────────────────────────────
void adjustHubOrbit(int frameId, int slot, float delta) {
  if (slot >= 0) {
    slotOrbitR[slot] = max(20, slotOrbitR[slot] + delta);
  } else {
    switch (frameId) {
      case 0: spokeOrbitR    = max(60, spokeOrbitR    + delta); break;
      case 1: crossOrbitR    = max(60, crossOrbitR    + delta); break;
      case 2: twoInnerOrbitR = max(40, twoInnerOrbitR + delta); break;
    }
  }
}

// ── Init ──────────────────────────────────────────────────────────────────────
void initAllStates() {
  initSpokeState();
  initCrossState();
  initTwoState();
  initSlotStates();
}

void initSpokeState() {
  int needed = nSpoke + 1;
  if (spokeState != null && spokeState.length == needed) return;
  spokeState = new NodeState[needed];
  spokeState[0] = new NodeState("center", 50, 0);
  for (int i = 0; i < nSpoke; i++) {
    float ang = radians(180 + i * (360.0 / nSpoke));
    spokeState[i+1] = new NodeState("Node " + (char)('A'+i%26), 55, ang);
  }
}

void initCrossState() {
  int needed = nCross + 1;
  if (crossState != null && crossState.length == needed) return;
  crossState = new NodeState[needed];
  crossState[0] = new NodeState("center", 60, 0);
  for (int i = 0; i < nCross; i++) {
    float ang  = radians(i * (360.0 / nCross));
    float rSat = min(58, (TWO_PI * 185 / nCross) * 0.36);
    crossState[i+1] = new NodeState("Node " + (char)('A'+i%26), rSat, ang);
  }
}

void initTwoState() {
  int needed = 1 + nInner + nOuter;
  if (twoState != null && twoState.length == needed) return;
  twoState = new NodeState[needed];
  twoState[0] = new NodeState("center", 52, 0);
  for (int i = 0; i < nInner; i++) {
    float ang = radians(i * (360.0 / nInner));
    twoState[1+i] = new NodeState("Node " + (char)('A'+i%26), 38, ang);
  }
  for (int i = 0; i < nOuter; i++) {
    float ang = radians(-45) + i * radians(360.0 / nOuter);
    twoState[1+nInner+i] = new NodeState("Outer " + (char)('A'+i%26), 55, ang);
  }
}

void initSlotStates() {
  if (slotStates != null && slotStates.length == nOuter) return;
  slotStates = new NodeState[nOuter][];
  slotOrbitR = new float[nOuter];
  slotScale  = new float[nOuter];
  float refOrbit = 80.0;
  float boundR   = 55.0;
  for (int i = 0; i < nOuter; i++) {
    int type = (i < slotTypes.length) ? slotTypes[i] : SLOT_PLAIN;
    int sn   = (i < slotN.length)     ? slotN[i]     : 4;
    slotOrbitR[i] = refOrbit;
    slotScale[i]  = boundR / refOrbit;
    if (type == SLOT_PLAIN) {
      slotStates[i] = null;
    } else {
      slotStates[i] = new NodeState[sn + 1];
      slotStates[i][0] = new NodeState("center", 18, 0);
      for (int j = 0; j < sn; j++) {
        float ang = (type == SLOT_SPOKE)
          ? radians(180 + j * (360.0 / sn))
          : radians(j * (360.0 / sn));
        float rSat = min(16, (TWO_PI * refOrbit / sn) * 0.36);
        slotStates[i][j+1] = new NodeState("Node " + (char)('A'+j%26), max(10, rSat), ang);
      }
    }
  }
}
