// ── DiagramRenderer ───────────────────────────────────────────────────────────
// Renders Spoke and Cross flat diagrams, and provides the shared recursive
// sub-diagram drawing used by both flat frameworks and NestedDiagram.
//
// Hit target stateIdx encoding:
//   0..N           = direct index into active framework state array
//   >= NESTED_BASE = NESTED_BASE + ownerHitIdx*MAX_CHILDREN + childLocalIdx
// ─────────────────────────────────────────────────────────────────────────────

final int NESTED_BASE  = 100000;
final int MAX_CHILDREN = 64;

void drawNSpoke(int n) {
  if (spokeState == null || spokeState.length < n+1) return;
  drawNodesWithState(n, spokeState, spokeOrbitR, SLOT_SPOKE, 0);
}

void drawNCross(int n) {
  if (crossState == null || crossState.length < n+1) return;
  drawNodesWithState(n, crossState, crossOrbitR, SLOT_CROSS, 0);
}

void drawNodesWithState(int n, NodeState[] states, float orbitR,
                        int diagramType, int stateOffset) {
  NodeState hub = states[0];
  styledOrbit(0, 0, orbitR, hub);

  for (int i = 0; i < n; i++) {
    NodeState ns = states[i+1];
    float angle = ns.ang + hub.subAngOffset;
    float sx =  orbitR * sin(angle);
    float sy = -orbitR * cos(angle);

    if (diagramType == SLOT_CROSS) {
      float off=7, aHead=7;
      float dx=sin(angle), dy=-cos(angle);
      float px=-dy*off, py=dx*off;
      float gapC=hub.r+4, gapS=ns.r+4;
      stroke(FG); strokeWeight(1.3);
      arrow(dx*gapC+px, dy*gapC+py, sx-dx*gapS+px, sy-dy*gapS+py, aHead);
      arrow(sx-dx*gapS-px, sy-dy*gapS-py, dx*gapC-px, dy*gapC-py, aHead);
    }

    int hitIdx = hitCount;
    registerHitTarget(sx, sy, ns.r, stateOffset + i+1);

    if (ns.isHub()) drawSubDiagram(ns, sx, sy, hitIdx, angle);
    else            styledNode(sx, sy, ns);
  }

  registerHitTarget(0, 0, hub.r, stateOffset + 0);
  styledNode(0, 0, hub);
}

// Draw a hub node's visual (node + orbit ring) then recurse into its satellites.
// cx, cy are in screen-centred coordinates relative to the inspectorCX/CY origin.
// hubAngle is the absolute outward-facing angle used to rotate the satellite
// cluster so it faces away from the root centre.
void drawSubDiagram(NodeState ns, float cx, float cy, int ownerHitIdx, float hubAngle) {
  styledNode(cx, cy, ns);
  if (appMode==1 && ns.viewCollapsed) { drawViewHubTint(cx, cy, ns); return; }
  float screenOrbitR = ns.subOrbitR * ns.subScale;
  noFill(); stroke(ns.orbitCol); strokeWeight(1);
  if (ns.orbitDashed) dashedCircle(cx, cy, screenOrbitR, 7, 5);
  else                ellipse(cx, cy, screenOrbitR*2, screenOrbitR*2);
  drawSubDiagramContents(ns, cx, cy, ownerHitIdx, hubAngle);
}

// Register hit targets and draw satellites for hub ns at screen position (cx, cy).
// hubAngle rotates every satellite by the hub's absolute outward angle + user offset,
// so sub-diagrams face away from the root centre instead of always pointing north.
void drawSubDiagramContents(NodeState ns, float cx, float cy, int ownerHitIdx, float hubAngle) {
  float sc = ns.subScale;
  int   n  = ns.numSatellites();

  int[]   childHitIdx = new int[n];
  float[] childSX     = new float[n];
  float[] childSY     = new float[n];
  float[] childAngle  = new float[n];

  pushMatrix();
    translate(cx, cy);
    scale(sc);

    for (int i = 0; i < n; i++) {
      NodeState child = ns.children[i+1];
      float angle = child.ang + hubAngle + ns.subAngOffset;
      childAngle[i] = angle;
      float lx =  ns.subOrbitR * sin(angle);
      float ly = -ns.subOrbitR * cos(angle);
      childSX[i] = cx + lx * sc;
      childSY[i] = cy + ly * sc;

      if (ns.subType == SLOT_CROSS) {
        float off=7, aHead=7;
        float dx=sin(angle), dy=-cos(angle);
        float px=-dy*off, py=dx*off;
        float gapC=ns.r/sc+4, gapS=child.r+4;
        stroke(FG); strokeWeight(1.3);
        arrow(dx*gapC+px, dy*gapC+py, lx-dx*gapS+px, ly-dy*gapS+py, aHead);
        arrow(lx-dx*gapS-px, ly-dy*gapS-py, dx*gapC-px, dy*gapC-py, aHead);
      }

      int childStIdx = NESTED_BASE + ownerHitIdx*MAX_CHILDREN + (i+1);
      childHitIdx[i] = hitCount;
      registerHitTarget(lx, ly, child.r, childStIdx);

      styledNode(lx, ly, child);
      if (child.isHub() && appMode==1 && child.viewCollapsed) drawViewHubTint(lx, ly, child);
    }
  popMatrix();

  for (int i = 0; i < n; i++) {
    NodeState child = ns.children[i+1];
    hitTargets[childHitIdx[i]][0] = inspectorCX + childSX[i];
    hitTargets[childHitIdx[i]][1] = inspectorCY + childSY[i];
    hitTargets[childHitIdx[i]][2] = child.r * sc;

    if (child.isHub() && !(appMode==1 && child.viewCollapsed)) {
      float childOrbitR = child.subOrbitR * child.subScale;
      noFill(); stroke(child.orbitCol); strokeWeight(1);
      if (child.orbitDashed) dashedCircle(childSX[i], childSY[i], childOrbitR, 7, 5);
      else                   ellipse(childSX[i], childSY[i], childOrbitR*2, childOrbitR*2);
      drawSubDiagramContents(child, childSX[i], childSY[i], childHitIdx[i], childAngle[i]);
    }
  }
}
