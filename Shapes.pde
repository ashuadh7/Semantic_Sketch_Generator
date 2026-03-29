// ── Shapes ────────────────────────────────────────────────────────────────────
// Sketch entry point: setup, draw loop, input handlers, and mode toggle bar.
// All other concerns are in dedicated files:
//   AppState.pde      — diagram config, node arrays, init, file-dialog callbacks
//   NodeState.pde     — NodeState data model
//   Inspector.pde     — sidebar UI, hit detection, node editing
//   SaveLoad.pde      — JSON session save/load, PNG export, serialisation
//   DrawUtils.pde     — shared drawing primitives (styledNode, arrow, etc.)
//   ViewMode.pde      — view-mode state, collapse/expand, View HUD
//   DiagramRenderer.pde — Spoke / Cross renderers + recursive sub-diagram
//   NestedDiagram.pde — infinitely-nested hub diagram renderer (Frame 2)
// ─────────────────────────────────────────────────────────────────────────────

// ── Global palette ────────────────────────────────────────────────────────────
int BG=255, FG=30, MUTED=120, BORDER=180;

// ── Button bar layout ─────────────────────────────────────────────────────────
final int numButtons = 2;
float btnW, btnH=64, btnGap=12, btnTop=20, canvasY;

// ── Edit mode pan/zoom ────────────────────────────────────────────────────────
float   editZoom=1.0, editPanX=0, editPanY=0;
boolean editIsPanning=false;

// ─────────────────────────────────────────────────────────────────────────────
void setup() {
  size(1060, 880);
  // Ensure data subfolders exist
  java.io.File dataDir = new java.io.File(sketchPath("data"));
  if (!dataDir.exists()) dataDir.mkdir();
  new java.io.File(sketchPath("data/assets")).mkdirs();
  new java.io.File(sketchPath("data/states")).mkdirs();
  new java.io.File(sketchPath("data/exports")).mkdirs();
  btnW = 120;
  canvasY = btnTop + btnH + btnGap + 16;
  textFont(createFont("Helvetica", 13));
  smooth(); initAllStates();
}

void draw() {
  background(BG); drawButtons();
  if (appMode == 0) {
    // ── Edit mode ─────────────────────────────────────────────────────────
    inspectorCX = (width - SB_W) / 2.0;
    inspectorCY = canvasY + (height - 20 - canvasY) / 2.0;
    resetHitTargets(512);
    clip(0, (int)canvasY, width-SB_W, (int)(height-20-canvasY));
    pushMatrix();
      translate(inspectorCX+editPanX, inspectorCY+editPanY);
      scale(editZoom);
      drawFramework(activeFrame);
    popMatrix();
    noClip();
    for (int i = 0; i < hitCount; i++) {
      float wx = hitTargets[i][0]-inspectorCX, wy = hitTargets[i][1]-inspectorCY;
      hitTargets[i][0] = inspectorCX + editPanX + wx*editZoom;
      hitTargets[i][1] = inspectorCY + editPanY + wy*editZoom;
      hitTargets[i][2] *= editZoom;
    }
    // Reselect moved node after a swap
    if (pendingSelectNode != null) {
      for (int i = 0; i < hitCount; i++) {
        if (resolveHit((int)hitTargets[i][3]) == pendingSelectNode) { selectedNode=i; break; }
      }
      pendingSelectNode = null;
    }
    drawSelectionRing();
    drawHUD();
    sbResetZones(); drawSidebar();
    // Offset registered click zones to match scrolled sidebar position
    for (int i = 0; i < sbZoneCount; i++) sbZones[i][1] -= sidebarScrollY;
  } else {
    // ── View mode ─────────────────────────────────────────────────────────
    float ch      = height - canvasY - 48;
    float canvasR = min(width, ch) * 0.45;
    float ext     = viewExtent(twoState!=null && twoState.length>0 ? twoState[0] : null);
    float vs      = (ext > 0) ? canvasR/ext : 1.0;
    float ts      = vs * viewZoom;
    inspectorCX = width / 2.0;
    inspectorCY = canvasY + ch / 2.0;
    resetHitTargets(512);
    clip(0, (int)canvasY, width, (int)(vHudY()-4-canvasY));
    pushMatrix();
      translate(inspectorCX+viewPanX, inspectorCY+viewPanY);
      scale(ts);
      drawFramework(activeFrame);
    popMatrix();
    noClip();
    for (int i = 0; i < hitCount; i++) {
      float wx = hitTargets[i][0]-inspectorCX, wy = hitTargets[i][1]-inspectorCY;
      hitTargets[i][0] = inspectorCX + viewPanX + wx*ts;
      hitTargets[i][1] = inspectorCY + viewPanY + wy*ts;
      hitTargets[i][2] *= ts;
    }
    drawViewHUD();
  }
  drawToast();
}

void drawFramework(int id) {
  switch (id) {
    case 0: drawNSpoke(nSpoke);          break;
    case 1: drawNCross(nCross);          break;
    case 2: drawTwoLevel(nInner, nOuter); break;
    case 3: drawPlaceholder();           break;
  }
}

// ── Input ─────────────────────────────────────────────────────────────────────
void mousePressed() {
  if (appMode==0 && mouseX>=sbX()) { sbMousePressed(mouseX, mouseY); return; }
  for (int i = 0; i < numButtons; i++) {
    float x=btnX(i), y=btnTop;
    if (mouseX>x && mouseX<x+btnW && mouseY>y && mouseY<y+btnH) {
      if (i==0 && appMode!=0) { resetViewCollapsed(); editZoom=1; editPanX=0; editPanY=0; }
      if (i==1 && appMode!=1) { collapseAllForView(); viewZoom=1; viewPanX=0; viewPanY=0; }
      appMode = i; return;
    }
  }
  if (appMode == 0) {
    if (editingLabel)    commitLabelEdit(selectedNodeState());
    if (editingSubLabel) commitSubLabelEdit(selectedNodeState());
    if (editingFilename) commitFilenameEdit();
    selectedNode  = pickNode(mouseX, mouseY);
    editIsPanning = false;
  } else {
    viewIsDragging = false;
    if (vHudButtonHit(0,mouseX,mouseY)) { viewZoom=1; viewPanX=0; viewPanY=0; return; }
    if (vHudButtonHit(1,mouseX,mouseY)) { collapseAllForView(); return; }
    if (vHudButtonHit(2,mouseX,mouseY)) { resetViewCollapsed(); return; }
    if (vHudFnHit(mouseX,mouseY))   { editingFilename=true; return; }
    if (vHudSaveHit(mouseX,mouseY)) { commitFilenameEdit(); saveCanvasImage(filenameBuffer); return; }
    viewDragStartX = mouseX; viewDragStartY = mouseY;
  }
}

void mouseDragged() {
  if (appMode == 0) {
    if (mouseX >= sbX()) { sbMouseDragged(mouseX, mouseY); return; }
    if (mouseButton==CENTER || editIsPanning) {
      editIsPanning = true;
      editPanX += mouseX-pmouseX; editPanY += mouseY-pmouseY;
    }
    return;
  }
  viewIsDragging = true;
  viewPanX += mouseX-pmouseX; viewPanY += mouseY-pmouseY;
}

void mouseReleased() {
  if (appMode == 0) { editIsPanning=false; sbMouseReleased(); return; }
  if (!viewIsDragging) {
    int hit = pickNode(mouseX, mouseY);
    if (hit >= 0) {
      NodeState ns = resolveHit((int)hitTargets[hit][3]);
      if (ns != null && ns.isHub()) ns.viewCollapsed = !ns.viewCollapsed;
    }
  }
  viewIsDragging = false;
}

void mouseWheel(MouseEvent e) {
  // Route to sidebar scroll when cursor is over the sidebar (edit mode only)
  if (appMode == 0 && mouseX >= sbX()) {
    float maxScroll = max(0, sidebarContentH - height);
    sidebarScrollY = constrain(sidebarScrollY + e.getCount() * 24, 0, maxScroll);
    return;
  }
  float factor = e.getCount() < 0 ? 1.1 : 0.9;
  if (appMode == 0) {
    float mx=mouseX-inspectorCX-editPanX, my=mouseY-inspectorCY-editPanY;
    editPanX -= mx*(factor-1); editPanY -= my*(factor-1);
    editZoom  = constrain(editZoom*factor, 0.1, 10);
  } else {
    float mx=mouseX-inspectorCX-viewPanX, my=mouseY-inspectorCY-viewPanY;
    viewPanX -= mx*(factor-1); viewPanY -= my*(factor-1);
    viewZoom  = constrain(viewZoom*factor, 0.1, 10);
  }
}

void keyPressed() {
  if (appMode != 0) { if (editingFilename) sbKeyPressed(); return; }
  if (sbKeyPressed()) return;
  if (key == TAB) { selectedNode = (hitCount>0) ? (selectedNode+1)%hitCount : -1; return; }
  if (key == ESC) { key=0; selectedNode=-1; return; }
  if (key == 26)  { undoGlobal(); return; }   // Ctrl+Z
  if (key == 25)  { redoGlobal(); return; }   // Ctrl+Y

  NodeState ns = selectedNodeState();
  if (ns == null) return;

  boolean ownsOrbit = ns.isHub() || (selectedOwner==null && selectedLocalIdx==0);
  switch (key) {
    case '[':
      pushUndoSnapshot(); ns.pushNodeSnapshot();
      ns.r = max(8, ns.r-2); ns.invalidateCache(); break;
    case ']':
      pushUndoSnapshot(); ns.pushNodeSnapshot();
      ns.r = ns.r+2; ns.invalidateCache(); break;
    case '{':
      if (ns.isHub()) { pushUndoSnapshot(); ns.r=max(8,ns.r*0.92); ns.invalidateCache(); ns.scaleProportional(0.92); }
      break;
    case '}':
      if (ns.isHub()) { pushUndoSnapshot(); ns.r=ns.r*1.08; ns.invalidateCache(); ns.scaleProportional(1.08); }
      break;
    case ',':
      if (ownsOrbit) { pushUndoSnapshot(); if (ns.isHub()) ns.subOrbitR=max(20,ns.subOrbitR-5); else adjustHubOrbit(activeFrame,-5); }
      break;
    case '.':
      if (ownsOrbit) { pushUndoSnapshot(); if (ns.isHub()) ns.subOrbitR+=5; else adjustHubOrbit(activeFrame,5); }
      break;
  }
}

// ── Mode toggle button bar ────────────────────────────────────────────────────
float btnX(int i) { return (width-(numButtons*btnW+(numButtons-1)*btnGap))/2.0 + i*(btnW+btnGap); }

void drawButtons() {
  String[] labels = {"Edit", "View"};
  for (int i = 0; i < numButtons; i++) {
    float x=btnX(i), y=btnTop; boolean active=(appMode==i);
    fill(active ? color(230,242,255) : color(245));
    stroke(active ? color(80,140,210) : BORDER); strokeWeight(active ? 1.8 : 0.8);
    rect(x, y, btnW, btnH, 10);
    fill(active ? color(30,80,160) : FG); noStroke(); textSize(13); textAlign(CENTER,CENTER);
    text(labels[i], x+btnW/2, y+btnH/2);
  }
}
