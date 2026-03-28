// ── Inspector + Sidebar ───────────────────────────────────────────────────────

int   selectedNode = -1;
float inspectorCX, inspectorCY;

float[][] hitTargets;
int       hitCount;

final int   SB_W    = 220;
final int   SB_PAD  = 14;
final color SB_BG   = color(248);
final color SB_LINE = color(210);

// ── Text editing state ────────────────────────────────────────────────────────
boolean editingLabel  = false;
String  editBuffer    = "";
int     cursorBlink   = 0;

void activateLabelEdit(NodeState ns) {
  editingLabel = true;
  editBuffer   = ns.label;
}

void commitLabelEdit(NodeState ns) {
  if (ns != null && editBuffer.length() > 0) ns.label = editBuffer;
  editingLabel = false;
}

// ── Hit targets ───────────────────────────────────────────────────────────────
void resetHitTargets(int maxNodes) {
  hitTargets = new float[maxNodes][4];
  hitCount   = 0;
}

void registerHitTarget(float wx, float wy, float r, int stateIdx) {
  if (hitCount >= hitTargets.length) return;
  hitTargets[hitCount][0] = inspectorCX + wx;
  hitTargets[hitCount][1] = inspectorCY + wy;
  hitTargets[hitCount][2] = r;
  hitTargets[hitCount][3] = stateIdx;
  hitCount++;
}

int selectedStateIdx() {
  if (selectedNode < 0 || selectedNode >= hitCount) return -1;
  return (int) hitTargets[selectedNode][3];
}

int[] decodeStateIdx(int stateIdx) {
  if (stateIdx >= SLOT_BASE) {
    int rel = stateIdx - SLOT_BASE;
    return new int[]{ rel / MAX_SLOT_NODES, rel % MAX_SLOT_NODES };
  }
  return new int[]{ -1, stateIdx };
}

NodeState selectedNodeState() {
  int stateIdx = selectedStateIdx();
  if (stateIdx < 0) return null;
  int[] dec = decodeStateIdx(stateIdx);
  int slot  = dec[0];
  int local = dec[1];
  if (slot >= 0) {
    if (slotStates == null || slot >= slotStates.length
        || slotStates[slot] == null || local >= slotStates[slot].length) return null;
    return slotStates[slot][local];
  }
  NodeState[] states = activeStates();
  if (states == null || local >= states.length) return null;
  return states[local];
}

boolean selectedIsHub() {
  int stateIdx = selectedStateIdx();
  if (stateIdx < 0) return false;
  return decodeStateIdx(stateIdx)[1] == 0;
}

float hubOrbitR() {
  if (!selectedIsHub()) return 0;
  int[] dec = decodeStateIdx(selectedStateIdx());
  int slot  = dec[0];
  if (slot >= 0) return (slotOrbitR != null) ? slotOrbitR[slot] : 0;
  switch (activeFrame) {
    case 0: return spokeOrbitR;
    case 1: return crossOrbitR;
    case 2: return twoInnerOrbitR;
  }
  return 0;
}

void drawSelectionRing() {
  if (selectedNode < 0 || selectedNode >= hitCount) return;
  float sx = hitTargets[selectedNode][0];
  float sy = hitTargets[selectedNode][1];
  float r  = hitTargets[selectedNode][2];
  noFill(); stroke(60, 120, 220); strokeWeight(2.5);
  ellipse(sx, sy, (r+8)*2, (r+8)*2);
}

void drawHUD() {
  fill(MUTED); noStroke(); textSize(11); textAlign(CENTER, BOTTOM);
  if (selectedNodeState() == null) {
    text("Click a node to select  ·  [ ] radius  ·  , . orbit (hub)  ·  Tab  ·  Esc",
         (width - SB_W) / 2.0, height - 8);
    return;
  }
  if (editingLabel) {
    fill(color(30,80,180)); noStroke(); textSize(11); textAlign(CENTER, BOTTOM);
    text("Editing label — Enter to confirm  ·  Esc to cancel",
         (width - SB_W) / 2.0, height - 8);
    return;
  }
  int[] dec = decodeStateIdx(selectedStateIdx());
  int local = dec[1];
  boolean isHub = (local == 0);
  NodeState ns = selectedNodeState();
  fill(color(30,80,180));
  String hud = "● " + ns.label
             + "   r=" + nf(ns.r,0,1)
             + (isHub && hubOrbitR()>0 ? "  orbit="+nf(hubOrbitR(),0,1) : "")
             + "  [ ] resize" + (isHub ? "  , . orbit" : "")
             + "  Tab  Esc";
  text(hud, (width - SB_W) / 2.0, height - 8);
}

int pickNode(float mx, float my) {
  for (int i = 0; i < hitCount; i++) {
    float dx = mx - hitTargets[i][0];
    float dy = my - hitTargets[i][1];
    if (dx*dx + dy*dy <= hitTargets[i][2]*hitTargets[i][2]) return i;
  }
  return -1;
}

// ── Sidebar ───────────────────────────────────────────────────────────────────

float sbX() { return width - SB_W; }

void drawSidebar() {
  float x = sbX();
  fill(SB_BG); noStroke();
  rect(x, 0, SB_W, height);
  stroke(SB_LINE); strokeWeight(1);
  line(x, 0, x, height);

  NodeState ns = selectedNodeState();
  if (ns == null) {
    fill(MUTED); noStroke(); textSize(12); textAlign(CENTER, CENTER);
    text("Select a node\nto edit properties", x + SB_W/2.0, height/2.0);
    return;
  }

  int[] dec    = decodeStateIdx(selectedStateIdx());
  int   slot   = dec[0];
  int   local  = dec[1];
  boolean isHub = (local == 0);

  float y = 20;

  // ── Title ──────────────────────────────────────────────────────────────────
  fill(FG); noStroke(); textSize(13); textAlign(LEFT, TOP);
  text(ns.label, x + SB_PAD, y);
  fill(MUTED); textSize(10);
  text(isHub ? "hub" : "satellite", x + SB_PAD, y + 16);
  y += 38;
  sbDivider(y); y += 12;

  // ── Label editor ───────────────────────────────────────────────────────────
  y = sbSectionLabel("Label", x, y);

  // Text field
  boolean fieldActive = editingLabel;
  fill(fieldActive ? color(230,240,255) : color(238));
  stroke(fieldActive ? color(80,140,210) : color(200));
  strokeWeight(fieldActive ? 1.8 : 1);
  rect(x + SB_PAD, y, SB_W - SB_PAD*2, 24, 4);

  String displayed = fieldActive ? editBuffer : ns.label;
  String cursor    = (fieldActive && frameCount % 60 < 30) ? "|" : "";
  fill(FG); noStroke(); textSize(12); textAlign(LEFT, CENTER);
  text(displayed + cursor, x + SB_PAD + 6, y + 12);

  sbRegisterClick(x + SB_PAD, y, SB_W - SB_PAD*2, 24, "LABEL_FIELD");
  y += 32;
  sbDivider(y); y += 12;

  // ── Node appearance ────────────────────────────────────────────────────────
  y = sbSectionLabel("Node", x, y);
  y = sbColorRow("Fill", ns.fillCol, "NODE_COLOR", x, y, ns);
  y = sbAlphaSlider("Alpha (overlay)", ns.alpha, "NODE_ALPHA", x, y);
  y = sbShapeRow(ns.shapeType, x, y);
  y += 4;
  sbDivider(y); y += 12;

  // ── Image ──────────────────────────────────────────────────────────────────
  y = sbSectionLabel("Image", x, y);

  // Preview or placeholder
  float previewSize = 60;
  float previewX    = x + SB_W/2.0 - previewSize/2.0;
  if (ns.img != null) {
    ns.rebuildMask((int)previewSize);
    if (ns.cropToShape && ns.imgMasked != null) {
      image(ns.imgMasked, previewX, y, previewSize, previewSize);
    } else {
      // Fit mode preview: scale to diagonal
      float aspect = (float)ns.img.width / ns.img.height;
      float pH = previewSize / sqrt(aspect*aspect + 1);
      float pW = pH * aspect;
      image(ns.img, previewX + (previewSize-pW)/2, y + (previewSize-pH)/2, pW, pH);
    }
    stroke(200); strokeWeight(1); noFill();
    if (ns.cropToShape) ellipse(previewX + previewSize/2, y + previewSize/2, previewSize, previewSize);
    else rect(previewX, y, previewSize, previewSize, 4);
  } else {
    fill(230); stroke(200); strokeWeight(1);
    rect(previewX, y, previewSize, previewSize, 6);
    fill(MUTED); noStroke(); textSize(10); textAlign(CENTER, CENTER);
    text("no image", previewX + previewSize/2, y + previewSize/2);
  }
  y += previewSize + 8;

  // Add / Remove buttons
  float btnW2 = (SB_W - SB_PAD*2 - 4) / 2.0;
  sbButton("Add image…", x + SB_PAD,          y, btnW2, 24, "IMG_ADD", false);
  sbButton("Remove",     x + SB_PAD + btnW2+4, y, btnW2, 24, "IMG_REMOVE", ns.img == null);
  y += 32;

  // Crop toggle (only if image present)
  y = sbToggle("Crop to shape", ns.cropToShape, "IMG_CROP", x, y, ns.img == null);
  y += 4;
  sbDivider(y); y += 12;

  // ── Orbit (hub only) ───────────────────────────────────────────────────────
  float hubOrb = hubOrbitR();
  boolean showOrbit = isHub && hubOrb > 0;
  y = sbSectionLabel("Orbit", x, y, showOrbit);

  if (showOrbit) {
    y = sbColorRow("Color", ns.orbitCol, "ORBIT_COLOR", x, y, ns);
    y = sbOrbitTypeRow(ns.orbitDashed, x, y);
  } else {
    fill(MUTED); noStroke(); textSize(11); textAlign(LEFT, TOP);
    text("(satellites only)", x + SB_PAD, y);
    y += 20;
  }
  y += 4;
  sbDivider(y); y += 12;

  // ── Diagram type stubs ─────────────────────────────────────────────────────
  y = sbSectionLabel("Diagram type", x, y);
  sbStubRow("Expand to sub-diagram", x, y); y += 28;
  sbStubRow("Change type / n",       x, y);
}

// ── Sidebar component helpers ─────────────────────────────────────────────────

void sbDivider(float y) {
  stroke(SB_LINE); strokeWeight(1);
  line(sbX(), y, sbX() + SB_W, y);
}

float sbSectionLabel(String label, float x, float y) {
  return sbSectionLabel(label, x, y, true);
}
float sbSectionLabel(String label, float x, float y, boolean active) {
  fill(active ? color(80,130,200) : MUTED);
  noStroke(); textSize(10); textAlign(LEFT, TOP);
  text(label.toUpperCase(), x + SB_PAD, y);
  return y + 18;
}

float sbColorRow(String label, color current, String tag, float x, float y, NodeState ns) {
  fill(MUTED); noStroke(); textSize(11); textAlign(LEFT, TOP);
  text(label, x + SB_PAD, y);
  color[] cols = { color(200,70,70), color(160), color(70,170,100) };
  float sw = 22; float gap = 6;
  float startX = x + SB_W - SB_PAD - (sw+gap)*3 + gap;
  for (int i = 0; i < 3; i++) {
    float sx = startX + i*(sw+gap);
    boolean sel = (int)red(current)==(int)red(cols[i])
               && (int)green(current)==(int)green(cols[i])
               && (int)blue(current)==(int)blue(cols[i]);
    fill(cols[i]); stroke(sel ? color(40,80,180) : color(180));
    strokeWeight(sel ? 2.5 : 1);
    rect(sx, y-1, sw, sw, 4);
    sbRegisterClick(sx, y-1, sw, sw, tag+"_"+i);
  }
  return y + sw + 6;
}

float sbAlphaSlider(String label, int current, String tag, float x, float y) {
  fill(MUTED); noStroke(); textSize(11); textAlign(LEFT, TOP);
  text(label, x + SB_PAD, y);
  fill(FG); textAlign(RIGHT, TOP);
  text(current, x + SB_W - SB_PAD, y);
  y += 16;
  float tx = x + SB_PAD;
  float tw = SB_W - SB_PAD*2;
  float th = 6;
  fill(210); noStroke(); rect(tx, y, tw, th, 3);
  fill(100,140,220); rect(tx, y, tw*(current/255.0), th, 3);
  float thumbX = tx + tw*(current/255.0);
  fill(255); stroke(150); strokeWeight(1.5);
  ellipse(thumbX, y+th/2, 12, 12);
  sbRegisterClick(tx, y-16, tw, th+20, tag);
  return y + th + 12;
}

float sbShapeRow(int current, float x, float y) {
  fill(MUTED); noStroke(); textSize(11); textAlign(LEFT, TOP);
  text("Shape", x + SB_PAD, y);
  y += 16;
  String[] labels = { "●", "▬", "◆" };
  int[]    types  = { SHAPE_CIRCLE, SHAPE_RECT, SHAPE_DIAMOND };
  float    bw     = (SB_W - SB_PAD*2 - 8) / 3.0;
  for (int i = 0; i < 3; i++) {
    float bx = x + SB_PAD + i*(bw+4);
    boolean sel = (current == types[i]);
    fill(sel ? color(210,230,255) : color(235));
    stroke(sel ? color(80,140,210) : color(200));
    strokeWeight(sel ? 1.8 : 1);
    rect(bx, y, bw, 26, 5);
    fill(sel ? color(30,80,160) : FG);
    noStroke(); textSize(14); textAlign(CENTER, CENTER);
    text(labels[i], bx+bw/2, y+13);
    sbRegisterClick(bx, y, bw, 26, "SHAPE_"+i);
  }
  return y + 32;
}

float sbOrbitTypeRow(boolean dashed, float x, float y) {
  fill(MUTED); noStroke(); textSize(11); textAlign(LEFT, TOP);
  text("Orbit line", x + SB_PAD, y);
  y += 16;
  String[] labels = { "- - -", "───" };
  boolean[] vals  = { true, false };
  float bw = (SB_W - SB_PAD*2 - 4) / 2.0;
  for (int i = 0; i < 2; i++) {
    float bx = x + SB_PAD + i*(bw+4);
    boolean sel = (dashed == vals[i]);
    fill(sel ? color(210,230,255) : color(235));
    stroke(sel ? color(80,140,210) : color(200));
    strokeWeight(sel ? 1.8 : 1);
    rect(bx, y, bw, 26, 5);
    fill(sel ? color(30,80,160) : FG);
    noStroke(); textSize(11); textAlign(CENTER, CENTER);
    text(labels[i], bx+bw/2, y+13);
    sbRegisterClick(bx, y, bw, 26, "ORBIT_TYPE_"+i);
  }
  return y + 32;
}

float sbToggle(String label, boolean state, String tag, float x, float y, boolean disabled) {
  fill(disabled ? color(200) : MUTED); noStroke(); textSize(11); textAlign(LEFT, CENTER);
  text(label, x + SB_PAD, y + 10);
  float tx = x + SB_W - SB_PAD - 36;
  float ty = y + 2;
  fill(disabled ? color(220) : (state ? color(80,160,100) : color(190)));
  noStroke(); rect(tx, ty, 36, 16, 8);
  fill(255); noStroke();
  ellipse(state ? tx+26 : tx+10, ty+8, 12, 12);
  if (!disabled) sbRegisterClick(tx, ty, 36, 16, tag);
  return y + 26;
}

void sbButton(String label, float x, float y, float w, float h, String tag, boolean disabled) {
  fill(disabled ? color(225) : color(235));
  stroke(disabled ? color(210) : color(190));
  strokeWeight(1); rect(x, y, w, h, 4);
  fill(disabled ? color(180) : FG);
  noStroke(); textSize(11); textAlign(CENTER, CENTER);
  text(label, x+w/2, y+h/2);
  if (!disabled) sbRegisterClick(x, y, w, h, tag);
}

void sbStubRow(String label, float x, float y) {
  fill(color(220)); noStroke();
  rect(x + SB_PAD, y, SB_W - SB_PAD*2, 22, 4);
  fill(MUTED); textSize(10); textAlign(LEFT, CENTER);
  text(label + " (soon)", x + SB_PAD + 6, y + 11);
}

// ── Click zone registry ───────────────────────────────────────────────────────
final int MAX_SB_ZONES = 80;
float[][] sbZones    = new float[MAX_SB_ZONES][4];
String[]  sbZoneTags = new String[MAX_SB_ZONES];
int       sbZoneCount = 0;

void sbResetZones() { sbZoneCount = 0; }

void sbRegisterClick(float x, float y, float w, float h, String tag) {
  if (sbZoneCount >= MAX_SB_ZONES) return;
  sbZones[sbZoneCount][0] = x;
  sbZones[sbZoneCount][1] = y;
  sbZones[sbZoneCount][2] = w;
  sbZones[sbZoneCount][3] = h;
  sbZoneTags[sbZoneCount] = tag;
  sbZoneCount++;
}

String sbPickZone(float mx, float my) {
  for (int i = 0; i < sbZoneCount; i++) {
    if (mx >= sbZones[i][0] && mx <= sbZones[i][0]+sbZones[i][2] &&
        my >= sbZones[i][1] && my <= sbZones[i][1]+sbZones[i][3])
      return sbZoneTags[i];
  }
  return null;
}

void sbHandleClick(String tag, float mx, float my) {
  if (tag == null) return;
  NodeState ns = selectedNodeState();
  if (ns == null) return;

  color[] cols = { color(200,70,70), color(160), color(70,170,100) };

  if (tag.equals("LABEL_FIELD")) {
    activateLabelEdit(ns);
  } else if (tag.startsWith("NODE_COLOR_")) {
    int idx = int(tag.charAt(tag.length()-1)) - int('0');
    ns.fillCol = cols[idx];
  } else if (tag.startsWith("ORBIT_COLOR_")) {
    int idx = int(tag.charAt(tag.length()-1)) - int('0');
    ns.orbitCol = cols[idx];
  } else if (tag.startsWith("SHAPE_")) {
    int idx = int(tag.charAt(tag.length()-1)) - int('0');
    ns.shapeType = idx;
  } else if (tag.startsWith("ORBIT_TYPE_")) {
    int idx = int(tag.charAt(tag.length()-1)) - int('0');
    ns.orbitDashed = (idx == 0);
  } else if (tag.equals("NODE_ALPHA")) {
    float tx = sbX() + SB_PAD;
    float tw = SB_W - SB_PAD*2;
    ns.alpha = (int)constrain(map(mx, tx, tx+tw, 0, 255), 0, 255);
  } else if (tag.equals("IMG_ADD")) {
    pendingImageNode = ns;
    selectInput("Select an image", "imageSelected");
  } else if (tag.equals("IMG_REMOVE")) {
    ns.img = null; ns.invalidateCache();
  } else if (tag.equals("IMG_CROP")) {
    ns.cropToShape = !ns.cropToShape;
    ns.invalidateCache();
  }
}

boolean sbDragging = false;
String  sbDragTag  = null;

void sbMousePressed(float mx, float my) {
  String tag = sbPickZone(mx, my);
  sbDragTag  = tag;
  sbDragging = true;
  sbHandleClick(tag, mx, my);
}

void sbMouseDragged(float mx, float my) {
  if (!sbDragging || sbDragTag == null) return;
  if (sbDragTag.equals("NODE_ALPHA")) {
    NodeState ns = selectedNodeState();
    if (ns == null) return;
    float tx = sbX() + SB_PAD;
    float tw = SB_W - SB_PAD*2;
    ns.alpha = (int)constrain(map(mx, tx, tx+tw, 0, 255), 0, 255);
  }
}

void sbMouseReleased() { sbDragging = false; sbDragTag = null; }

// ── Key handler for label editing (called from Shapes.pde keyPressed) ─────────
boolean sbKeyPressed() {
  if (!editingLabel) return false;
  NodeState ns = selectedNodeState();
  if (key == ENTER || key == RETURN) { commitLabelEdit(ns); return true; }
  if (key == ESC)  { editingLabel = false; key = 0; return true; }
  if (key == BACKSPACE) {
    if (editBuffer.length() > 0)
      editBuffer = editBuffer.substring(0, editBuffer.length()-1);
    return true;
  }
  if (key >= 32 && key < 127) { editBuffer += key; return true; }
  return true;
}
