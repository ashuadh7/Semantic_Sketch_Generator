// ── ViewMode ──────────────────────────────────────────────────────────────────
// View-mode pan/zoom state, hub collapse/expand helpers, and View HUD.
// ─────────────────────────────────────────────────────────────────────────────

// ── View mode state ───────────────────────────────────────────────────────────
float   viewZoom=1.0, viewPanX=0, viewPanY=0;
boolean viewIsDragging=false;
float   viewDragStartX, viewDragStartY;

// ── Collapse / expand ─────────────────────────────────────────────────────────
void resetViewCollapsed()                   { resetViewCollapsedRec(twoState); }
void resetViewCollapsedRec(NodeState[] arr) {
  if (arr == null) return;
  for (NodeState ns : arr) { ns.viewCollapsed=false; if (ns.isHub()) resetViewCollapsedRec(ns.children); }
}

void collapseAllForView()                   { collapseAllRec(twoState); }
void collapseAllRec(NodeState[] arr)        {
  if (arr == null) return;
  for (NodeState ns : arr) { if (ns.isHub()) { ns.viewCollapsed=true; collapseAllRec(ns.children); } }
}

// Max screen-space radius from a node's centre given current viewCollapsed state
float viewExtent(NodeState ns) {
  if (ns == null) return 0;
  if (!ns.isHub() || ns.viewCollapsed) return ns.r;
  float orbitR = ns.subOrbitR * ns.subScale, maxExt = ns.r;
  for (int i = 1; i < ns.children.length; i++) {
    NodeState c = ns.children[i];
    maxExt = max(maxExt, orbitR + (c.isHub() && !c.viewCollapsed ? viewExtent(c) : c.r*ns.subScale));
  }
  return maxExt;
}

// Blue tint overlay drawn on top of styledNode for any collapsed hub in View mode
void drawViewHubTint(float cx, float cy, NodeState ns) {
  fill(color(80,140,210,50)); noStroke(); drawShape(cx, cy, ns);
}

// ── View HUD ─────────────────────────────────────────────────────────────────
// Left group: Reset zoom · Collapse all · Expand all
// Right group: [filename field]  [Export PNG]
final String[] VHD_LABELS = {"Reset zoom", "Collapse all", "Expand all"};
final float VHD_BTN_W=100, VHD_BTN_H=28, VHD_BTN_GAP=10;
final float VHD_FN_W=180, VHD_SAVE_W=100;

float vHudY()     { return height - 44; }

float vHudBtnX(int i) {
  float leftGroupW = VHD_BTN_W*3 + VHD_BTN_GAP*2;
  float leftStart  = (width/2.0 - 10 - leftGroupW) / 2.0;
  return leftStart + i*(VHD_BTN_W + VHD_BTN_GAP);
}
float vHudFnX()   { return width - 16 - VHD_SAVE_W - 8 - VHD_FN_W; }
float vHudSaveX() { return width - 16 - VHD_SAVE_W; }

void drawViewHUD() {
  fill(248); noStroke(); rect(0, vHudY()-4, width, height-vHudY()+4);
  stroke(SB_LINE); strokeWeight(1); line(0, vHudY()-4, width, vHudY()-4);

  // Left button group
  for (int i = 0; i < 3; i++) {
    boolean hov = vHudButtonHit(i, mouseX, mouseY);
    fill(hov ? color(220,235,255) : color(238));
    stroke(hov ? color(80,140,210) : BORDER); strokeWeight(hov ? 1.8 : 1);
    rect(vHudBtnX(i), vHudY(), VHD_BTN_W, VHD_BTN_H, 5);
    fill(hov ? color(30,80,160) : FG); noStroke(); textSize(11); textAlign(CENTER,CENTER);
    text(VHD_LABELS[i], vHudBtnX(i)+VHD_BTN_W/2, vHudY()+VHD_BTN_H/2);
  }

  // Filename field
  float fy=vHudY(), fx=vHudFnX();
  boolean fe = editingFilename;
  fill(fe ? color(230,240,255) : color(238));
  stroke(fe ? color(80,140,210) : color(200)); strokeWeight(fe ? 1.8 : 1);
  rect(fx, fy, VHD_FN_W, VHD_BTN_H, 4);
  String display = filenameBuffer.length()>0 ? filenameBuffer : "auto timestamp";
  fill(filenameBuffer.length()==0 && !fe ? MUTED : FG); noStroke(); textSize(11); textAlign(LEFT,CENTER);
  text((fe ? filenameBuffer : display) + (fe && frameCount%60<30 ? "|" : ""), fx+6, fy+VHD_BTN_H/2);

  // Export PNG button
  boolean shov = vHudSaveHit(mouseX, mouseY);
  fill(shov ? color(220,235,255) : color(238));
  stroke(shov ? color(80,140,210) : BORDER); strokeWeight(shov ? 1.8 : 1);
  rect(vHudSaveX(), fy, VHD_SAVE_W, VHD_BTN_H, 5);
  fill(shov ? color(30,80,160) : FG); noStroke(); textSize(11); textAlign(CENTER,CENTER);
  text("Export PNG", vHudSaveX()+VHD_SAVE_W/2, fy+VHD_BTN_H/2);
}

boolean vHudButtonHit(int i, float mx, float my) {
  float x=vHudBtnX(i), y=vHudY();
  return mx>=x && mx<=x+VHD_BTN_W && my>=y && my<=y+VHD_BTN_H;
}
boolean vHudFnHit(float mx, float my) {
  return mx>=vHudFnX() && mx<=vHudFnX()+VHD_FN_W && my>=vHudY() && my<=vHudY()+VHD_BTN_H;
}
boolean vHudSaveHit(float mx, float my) {
  return mx>=vHudSaveX() && mx<=vHudSaveX()+VHD_SAVE_W && my>=vHudY() && my<=vHudY()+VHD_BTN_H;
}
