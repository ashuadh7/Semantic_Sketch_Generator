// ── NestedDiagram ─────────────────────────────────────────────────────────────
// Renders Frame 2: the infinitely-deep nested hub diagram.
// Starts as a single hub node; users add satellites via the sidebar.
// Each node can be promoted to a sub-diagram — recursion is handled by
// drawSubDiagram / drawSubDiagramContents in DiagramRenderer.pde.
// ─────────────────────────────────────────────────────────────────────────────

final int SLOT_BASE      = 1000;
final int MAX_SLOT_NODES = 32;

void drawTwoLevel(int nInner, int nOuter) {
  if (twoState == null || twoState.length < 1) return;
  NodeState hub = twoState[0];

  if (!hub.isHub()) {
    registerHitTarget(0, 0, hub.r, 0);
    styledNode(0, 0, hub);
    return;
  }

  int hubHitIdx = hitCount;
  registerHitTarget(0, 0, hub.r, 0);

  if (appMode==1 && hub.viewCollapsed) {
    styledNode(0, 0, hub);
    drawViewHubTint(0, 0, hub);
    return;
  }

  float screenOrbitR = hub.subOrbitR * hub.subScale;
  styledOrbit(0, 0, screenOrbitR, hub);

  int n = hub.numSatellites();
  for (int i = 0; i < n; i++) {
    NodeState child = hub.children[i+1];
    float sx =  screenOrbitR * sin(child.ang);
    float sy = -screenOrbitR * cos(child.ang);

    if (hub.subType == SLOT_CROSS) {
      float off=7, aHead=7;
      float dx=sin(child.ang), dy=-cos(child.ang);
      float px=-dy*off, py=dx*off;
      float gapC=hub.r+4, gapS=child.r*hub.subScale+4;
      stroke(FG); strokeWeight(1.3);
      arrow(dx*gapC+px, dy*gapC+py, sx-dx*gapS+px, sy-dy*gapS+py, aHead);
      arrow(sx-dx*gapS-px, sy-dy*gapS-py, dx*gapC-px, dy*gapC-py, aHead);
    }

    int childStIdx  = NESTED_BASE + hubHitIdx * MAX_CHILDREN + (i+1);
    int childHitIdx = hitCount;
    registerHitTarget(sx, sy, child.r * hub.subScale, childStIdx);

    if (child.isHub() && appMode==1 && child.viewCollapsed) {
      styledNode(sx, sy, child);
      drawViewHubTint(sx, sy, child);
    } else if (child.isHub()) {
      drawSubDiagram(child, sx, sy, childHitIdx, child.ang);
    } else {
      styledNode(sx, sy, child);
    }
  }

  styledNode(0, 0, hub);
}
