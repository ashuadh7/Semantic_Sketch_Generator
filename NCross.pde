void drawNCross(int n) {
  if (crossState == null || crossState.length < n+1) return;
  drawNCrossWithState(n, crossState, crossOrbitR, 0);
}

void drawNCrossWithState(int n, NodeState[] states, float orbitR, int stateOffset) {
  NodeState hub   = states[0];
  float     off   = 7;
  float     aHead = 7;

  styledOrbit(0, 0, orbitR, hub);

  for (int i = 0; i < n; i++) {
    NodeState ns = states[i+1];
    float sx =  orbitR * sin(ns.ang);
    float sy = -orbitR * cos(ns.ang);

    registerHitTarget(sx, sy, ns.r, stateOffset + i+1);
    styledNode(sx, sy, ns, "label");

    float dx =  sin(ns.ang);
    float dy = -cos(ns.ang);
    float px = -dy * off;
    float py =  dx * off;
    float gapC = hub.r + 4;
    float gapS = ns.r  + 4;

    stroke(FG); strokeWeight(1.3);
    arrow(dx*gapC+px,    dy*gapC+py,    sx-dx*gapS+px, sy-dy*gapS+py, aHead);
    arrow(sx-dx*gapS-px, sy-dy*gapS-py, dx*gapC-px,    dy*gapC-py,    aHead);
  }

  // Hub last
  registerHitTarget(0, 0, hub.r, stateOffset + 0);
  styledNode(0, 0, hub, "label");
}
