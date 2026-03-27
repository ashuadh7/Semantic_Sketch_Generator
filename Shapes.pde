// ─── Global palette ──────────────────────────────────────────────────────────
int BG     = 255;
int FG     = 30;
int MUTED  = 120;
int BORDER = 180;

final int SLOT_PLAIN = 0;
final int SLOT_CROSS = 1;
final int SLOT_SPOKE = 2;

int nSpoke = 4;
int nCross = 5;
int nInner = 4;
int nOuter = 4;

int[] slotTypes = { SLOT_CROSS, SLOT_SPOKE, SLOT_PLAIN, SLOT_PLAIN };
int[] slotN     = { 3,          5,           0,           0          };

int   activeFrame = -1;
int   numButtons  = 4;
float btnW, btnH  = 64;
float btnGap      = 12;
float btnTop      = 20;
float canvasY;

String[] btnLabels = {
  "n-spoke radial", "n-node cross", "two-level nested", "+ add framework"
};

void setup() {
  size(1020, 880);
  btnW    = ((width - SB_W) - (numButtons+1)*btnGap) / numButtons;
  canvasY = btnTop + btnH + btnGap + 16;
  textFont(createFont("Helvetica", 13));
  smooth();
  initAllStates();
}

void draw() {
  background(BG);
  drawButtons();

  // Canvas center excludes sidebar
  inspectorCX = (width - SB_W) / 2.0;
  inspectorCY = canvasY + (height - 20 - canvasY) / 2.0;

  if (activeFrame >= 0) {
    resetHitTargets(256);
    pushMatrix();
      translate(inspectorCX, inspectorCY);
      drawFramework(activeFrame);
    popMatrix();
    drawSelectionRing();
  } else {
    drawEmptyState();
  }

  drawHUD();

  // Sidebar — reset zones each frame then redraw
  sbResetZones();
  drawSidebar();
}

NodeState[] activeStates() {
  switch (activeFrame) {
    case 0: return spokeState;
    case 1: return crossState;
    case 2: return twoState;
    default: return null;
  }
}

void drawFramework(int id) {
  switch (id) {
    case 0: drawNSpoke(nSpoke);                             break;
    case 1: drawNCross(nCross);                             break;
    case 2: drawTwoLevel(nInner, nOuter, slotTypes, slotN); break;
    case 3: drawPlaceholder();                              break;
  }
}

// ─── Mouse ───────────────────────────────────────────────────────────────────
void mousePressed() {
  // Sidebar takes priority
  if (mouseX >= sbX()) {
    sbMousePressed(mouseX, mouseY);
    return;
  }
  // Buttons
  for (int i = 0; i < numButtons; i++) {
    float x = btnGap + i*(btnW+btnGap);
    float y = btnTop;
    if (mouseX>x && mouseX<x+btnW && mouseY>y && mouseY<y+btnH) {
      if (activeFrame != i) selectedNode = -1;
      activeFrame = (activeFrame==i) ? -1 : i;
      return;
    }
  }
  // Canvas node pick
  if (activeFrame >= 0) selectedNode = pickNode(mouseX, mouseY);
}

void mouseDragged() {
  if (mouseX >= sbX()) sbMouseDragged(mouseX, mouseY);
}

void mouseReleased() {
  sbMouseReleased();
}

// ─── Keyboard ────────────────────────────────────────────────────────────────
void keyPressed() {
  if (key == TAB) {
    selectedNode = (hitCount > 0) ? (selectedNode+1) % hitCount : -1;
    return;
  }
  if (key == ESC) { key=0; selectedNode=-1; return; }

  NodeState ns = selectedNodeState();
  if (ns == null) return;

  int[] dec  = decodeStateIdx(selectedStateIdx());
  int slot   = dec[0];
  int local  = dec[1];
  boolean isHub = (local == 0);

  switch (key) {
    case '[': ns.r = max(8, ns.r - 2); break;
    case ']': ns.r =        ns.r + 2;  break;
    case ',': if (isHub) adjustHubOrbit(activeFrame, slot, -5); break;
    case '.': if (isHub) adjustHubOrbit(activeFrame, slot,  5); break;
  }
}

// ─── Buttons ─────────────────────────────────────────────────────────────────
void drawButtons() {
  String[] meta = {
    "n = " + nSpoke + " spokes",
    "n = " + nCross + " nodes",
    twoLevelMeta(),
    "your next diagram"
  };
  for (int i = 0; i < numButtons; i++) {
    float   x      = btnGap + i*(btnW+btnGap);
    float   y      = btnTop;
    boolean active = (activeFrame == i);
    fill(active ? color(230,242,255) : color(245));
    stroke(active ? color(80,140,210) : BORDER);
    strokeWeight(active ? 1.8 : 0.8);
    rect(x, y, btnW, btnH, 10);
    fill(active ? color(30,80,160) : FG);
    noStroke(); textSize(13); textAlign(LEFT,TOP);
    text(btnLabels[i], x+12, y+12);
    fill(active ? color(80,130,200) : MUTED);
    textSize(11);
    text(meta[i], x+12, y+32);
  }
}

String twoLevelMeta() {
  int crosses=0, spokes=0;
  for (int t : slotTypes) {
    if      (t==SLOT_CROSS) crosses++;
    else if (t==SLOT_SPOKE) spokes++;
  }
  String s = nInner + " inner / " + nOuter + " outer";
  if (crosses>0) s += "  x"+crosses+"cross";
  if (spokes >0) s += "  x"+spokes +"spoke";
  return s;
}

void drawEmptyState() {
  fill(MUTED); noStroke(); textSize(13); textAlign(CENTER,CENTER);
  text("Select a framework above to preview it",
       (width-SB_W)/2.0, canvasY+(height-canvasY)/2.0);
}

void drawPlaceholder() {
  fill(MUTED); noStroke(); textSize(13); textAlign(CENTER,CENTER);
  text("This slot is empty — add your own framework here.", 0, 0);
}

// ─── Style-aware draw helpers ─────────────────────────────────────────────────

// Replaces labeledCircle — reads style from NodeState
void styledNode(float x, float y, NodeState ns, String sub) {
  color fc = color(red(ns.fillCol), green(ns.fillCol), blue(ns.fillCol), ns.alpha);
  fill(fc); stroke(BORDER); strokeWeight(1.5);

  if (ns.shapeType == SHAPE_RECT) {
    rectMode(CENTER);
    rect(x, y, ns.r*2, ns.r*2, ns.r*0.3);
    rectMode(CORNER);
  } else if (ns.shapeType == SHAPE_DIAMOND) {
    float r = ns.r;
    beginShape();
      vertex(x,   y-r);
      vertex(x+r, y);
      vertex(x,   y+r);
      vertex(x-r, y);
    endShape(CLOSE);
  } else {
    ellipse(x, y, ns.r*2, ns.r*2);
  }

  fill(FG); noStroke(); textSize(13); textAlign(CENTER,CENTER);
  text(ns.label, x, sub.isEmpty() ? y : y-8);
  if (!sub.isEmpty()) { fill(MUTED); textSize(11); text(sub, x, y+10); }
}

// Replaces dashedCircle — reads orbit style from NodeState
void styledOrbit(float x, float y, float r, NodeState hubNs) {
  color oc = hubNs.orbitCol;
  stroke(oc); strokeWeight(1); noFill();
  if (hubNs.orbitDashed) {
    dashedCircle(x, y, r, 7, 5);
  } else {
    ellipse(x, y, r*2, r*2);
  }
}

// Plain helpers still used internally
void dashedCircle(float x, float y, float r, float dashLen, float gapLen) {
  float step = dashLen/r + gapLen/r;
  noFill();
  for (float a=0; a<TWO_PI; a+=step)
    arc(x, y, r*2, r*2, a, min(a+dashLen/r, a+step-0.01));
}

void arrow(float x1, float y1, float x2, float y2, float headSize) {
  line(x1,y1,x2,y2);
  float ang = atan2(y2-y1,x2-x1);
  fill(FG); noStroke();
  triangle(x2,y2,
           x2-headSize*cos(ang-0.4),y2-headSize*sin(ang-0.4),
           x2-headSize*cos(ang+0.4),y2-headSize*sin(ang+0.4));
  stroke(FG); noFill();
}

// Keep for backward compat inside draw functions that still call it
void labeledCircle(float x, float y, float r, String title, String sub) {
  fill(245); stroke(BORDER); strokeWeight(1.5);
  ellipse(x, y, r*2, r*2);
  fill(FG); noStroke(); textSize(13); textAlign(CENTER,CENTER);
  text(title, x, sub.isEmpty() ? y : y-8);
  if (!sub.isEmpty()) { fill(MUTED); textSize(11); text(sub, x, y+10); }
}
