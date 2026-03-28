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

void drawSubDiagram(NodeState ns, float cx, float cy, int ownerHitIdx) {
  float sc = ns.subScale;
  int   n  = ns.numSatellites();

  // Draw node as hub visual
  styledNode(cx, cy, ns, "");

  // Orbit ring in screen space (outside scale matrix)
  float screenOrbitR = ns.subOrbitR * sc;
  noFill(); stroke(ns.orbitCol); strokeWeight(1);
  if (ns.orbitDashed) dashedCircle(cx, cy, screenOrbitR, 7, 5);
  else ellipse(cx, cy, screenOrbitR*2, screenOrbitR*2);

  pushMatrix();
    translate(cx, cy);
    scale(sc);

    for (int i = 0; i < n; i++) {
      NodeState child = ns.children[i+1];
      float sx =  ns.subOrbitR * sin(child.ang);
      float sy = -ns.subOrbitR * cos(child.ang);

      if (ns.subType == SLOT_CROSS) {
        float off=7, aHead=7;
        float dx=sin(child.ang), dy=-cos(child.ang);
        float px=-dy*off, py=dx*off;
        float gapC=ns.children[0].r+4, gapS=child.r+4;
        stroke(FG); strokeWeight(1.3);
        arrow(dx*gapC+px,dy*gapC+py,sx-dx*gapS+px,sy-dy*gapS+py,aHead);
        arrow(sx-dx*gapS-px,sy-dy*gapS-py,dx*gapC-px,dy*gapC-py,aHead);
      }

      int childStIdx  = NESTED_BASE + ownerHitIdx*MAX_CHILDREN + (i+1);
      int childHitIdx = hitCount;
      registerHitTarget(sx, sy, child.r, childStIdx);

      if (child.isHub()) drawSubDiagram(child, sx, sy, childHitIdx);
      else               styledNode(sx, sy, child, "label");
    }
  popMatrix();

  // Correct hit targets to screen space
  int startHit = hitCount - n;
  for (int i = 0; i < n; i++) {
    NodeState child = ns.children[i+1];
    float lx =  ns.subOrbitR * sin(child.ang);
    float ly = -ns.subOrbitR * cos(child.ang);
    hitTargets[startHit+i][0] = inspectorCX + cx + lx*sc;
    hitTargets[startHit+i][1] = inspectorCY + cy + ly*sc;
    hitTargets[startHit+i][2] = child.r * sc;
  }
}
