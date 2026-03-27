void drawNSpoke(int n) {
  if (spokeState == null || spokeState.length < n+1) return;
  drawNSpokeWithState(n, spokeState, spokeOrbitR, 0);
}

void drawNSpokeWithState(int n, NodeState[] states, float orbitR, int stateOffset) {
  NodeState hub = states[0];

  styledOrbit(0, 0, orbitR, hub);

  for (int i = 0; i < n; i++) {
    NodeState ns = states[i+1];
    float sx =  orbitR * sin(ns.ang);
    float sy = -orbitR * cos(ns.ang);
    registerHitTarget(sx, sy, ns.r, stateOffset + i+1);
    styledNode(sx, sy, ns, "label");
  }

  // Hub last
  registerHitTarget(0, 0, hub.r, stateOffset + 0);
  styledNode(0, 0, hub, "");
}
