// ── NSpoke / NCross unified renderer ─────────────────────────────────────────
// Hit target stateIdx encoding:
//   0..N           = direct index into active framework state array
//   >= NESTED_BASE = NESTED_BASE + ownerHitIdx*MAX_CHILDREN + childLocalIdx
// ─────────────────────────────────────────────────────────────────────────────

final int NESTED_BASE  = 100000;
final int MAX_CHILDREN = 64;

void drawNSpoke(int n) {
  if (spokeState==null||spokeState.length<n+1) return;
  drawNodesWithState(n, spokeState, spokeOrbitR, SLOT_SPOKE, 0);
}

void drawNCross(int n) {
  if (crossState==null||crossState.length<n+1) return;
  drawNodesWithState(n, crossState, crossOrbitR, SLOT_CROSS, 0);
}

void drawNodesWithState(int n, NodeState[] states, float orbitR,
                        int diagramType, int stateOffset) {
  NodeState hub = states[0];
  styledOrbit(0, 0, orbitR, hub);

  for (int i = 0; i < n; i++) {
    NodeState ns = states[i+1];
    float sx =  orbitR * sin(ns.ang);
    float sy = -orbitR * cos(ns.ang);

    if (diagramType == SLOT_CROSS) {
      float off=7, aHead=7;
      float dx=sin(ns.ang), dy=-cos(ns.ang);
      float px=-dy*off, py=dx*off;
      float gapC=hub.r+4, gapS=ns.r+4;
      stroke(FG); strokeWeight(1.3);
      arrow(dx*gapC+px,dy*gapC+py,sx-dx*gapS+px,sy-dy*gapS+py,aHead);
      arrow(sx-dx*gapS-px,sy-dy*gapS-py,dx*gapC-px,dy*gapC-py,aHead);
    }

    int hitIdx = hitCount;
    registerHitTarget(sx, sy, ns.r, stateOffset + i+1);

    if (ns.isHub()) drawSubDiagram(ns, sx, sy, hitIdx);
    else            styledNode(sx, sy, ns, "label");
  }

  registerHitTarget(0, 0, hub.r, stateOffset + 0);
  styledNode(0, 0, hub, "");
}

// Draw a hub node's visual (node circle + orbit ring) then hand off to drawSubDiagramContents.
// cx, cy are always in screen-centred coordinates (relative to inspectorCX/CY origin).
void drawSubDiagram(NodeState ns, float cx, float cy, int ownerHitIdx) {
  styledNode(cx, cy, ns, "");
  float screenOrbitR = ns.subOrbitR * ns.subScale;
  noFill(); stroke(ns.orbitCol); strokeWeight(1);
  if (ns.orbitDashed) dashedCircle(cx, cy, screenOrbitR, 7, 5);
  else                ellipse(cx, cy, screenOrbitR*2, screenOrbitR*2);
  drawSubDiagramContents(ns, cx, cy, ownerHitIdx);
}

// Register hit targets and draw satellites for hub ns at screen position (cx, cy).
// Hub children's visuals (node + orbit ring) are drawn inside the scale matrix so they
// inherit the correct visual scale.  The recursive call for their own children happens
// OUTSIDE the matrix with accumulated screen-space coordinates, fixing two bugs:
//
//   Bug 1 — "startHit = hitCount - n" formula:
//     Recursive calls inside the loop inflate hitCount by more than n, so the old
//     formula points at the wrong hit targets.  Fixed by recording each child's hit
//     index before registration and using that recorded index for correction.
//
//   Bug 2 — wrong coordinate space in recursive calls:
//     Calling drawSubDiagram from inside pushMatrix/scale passed local (unscaled) coords
//     as if they were screen coords.  Fixed by deferring recursion to after popMatrix
//     with the correct screen-space position (cx + lx*sc, cy + ly*sc).
void drawSubDiagramContents(NodeState ns, float cx, float cy, int ownerHitIdx) {
  float sc = ns.subScale;
  int   n  = ns.numSatellites();

  int[]   childHitIdx = new int[n];   // recorded before registration (fixes Bug 1)
  float[] childSX     = new float[n]; // screen-space X for each child (fixes Bug 2)
  float[] childSY     = new float[n];

  pushMatrix();
    translate(cx, cy);
    scale(sc);

    for (int i = 0; i < n; i++) {
      NodeState child = ns.children[i+1];
      float lx =  ns.subOrbitR * sin(child.ang);  // local coords (pre-scale)
      float ly = -ns.subOrbitR * cos(child.ang);
      childSX[i] = cx + lx * sc;  // accumulate to screen space for use after popMatrix
      childSY[i] = cy + ly * sc;

      if (ns.subType == SLOT_CROSS) {
        float off=7, aHead=7;
        float dx=sin(child.ang), dy=-cos(child.ang);
        float px=-dy*off, py=dx*off;
        float gapC=ns.r/sc+4, gapS=child.r+4;
        stroke(FG); strokeWeight(1.3);
        arrow(dx*gapC+px,dy*gapC+py,lx-dx*gapS+px,ly-dy*gapS+py,aHead);
        arrow(lx-dx*gapS-px,ly-dy*gapS-py,dx*gapC-px,dy*gapC-py,aHead);
      }

      int childStIdx = NESTED_BASE + ownerHitIdx*MAX_CHILDREN + (i+1);
      childHitIdx[i] = hitCount;              // record index BEFORE registering
      registerHitTarget(lx, ly, child.r, childStIdx);

      if (child.isHub()) {
        // Draw hub child's node and orbit ring here, inside the scale matrix,
        // so they appear at the correct visual scale.  Recursion into its own
        // children is deferred to after popMatrix (fixes Bug 2).
        styledNode(lx, ly, child, "");
        float childOrbitR = child.subOrbitR * child.subScale;
        noFill(); stroke(child.orbitCol); strokeWeight(1);
        if (child.orbitDashed) dashedCircle(lx, ly, childOrbitR, 7, 5);
        else                   ellipse(lx, ly, childOrbitR*2, childOrbitR*2);
      } else {
        styledNode(lx, ly, child, "label");
      }
    }
  popMatrix();

  // Correct every child's hit target using its recorded index (fixes Bug 1)
  // and accumulated screen coords (fixes Bug 2).
  // Then recurse for hub children outside the scale matrix.
  for (int i = 0; i < n; i++) {
    NodeState child = ns.children[i+1];
    hitTargets[childHitIdx[i]][0] = inspectorCX + childSX[i];
    hitTargets[childHitIdx[i]][1] = inspectorCY + childSY[i];
    hitTargets[childHitIdx[i]][2] = child.r * sc;

    if (child.isHub()) {
      // Recurse with screen-space coords — hub visual already drawn above
      drawSubDiagramContents(child, childSX[i], childSY[i], childHitIdx[i]);
    }
  }
}
