final int SLOT_BASE      = 1000;
final int MAX_SLOT_NODES = 32;

void drawTwoLevel(int nInner, int nOuter, int[] slotTypes, int[] slotN) {
  if (twoState == null || twoState.length < 1+nInner+nOuter) return;

  NodeState hub   = twoState[0];
  float     off   = 6;
  float     aHead = 7;

  // Enclosing circle uses hub's orbit style
  stroke(hub.orbitCol); strokeWeight(2); noFill();
  if (hub.orbitDashed) dashedCircle(0, 0, twoOuterOrbitR, 8, 6);
  else ellipse(0, 0, twoOuterOrbitR*2, twoOuterOrbitR*2);

  // ── Outer slots ─────────────────────────────────────────────────────────────
  for (int i = 0; i < nOuter; i++) {
    NodeState proxy = twoState[1+nInner+i];
    float ox =  twoOuterOrbitR * sin(proxy.ang);
    float oy = -twoOuterOrbitR * cos(proxy.ang);

    int type = (i < slotTypes.length) ? slotTypes[i] : SLOT_PLAIN;
    int sn   = (i < slotN.length)     ? slotN[i]     : 4;

    if (type == SLOT_PLAIN) {
      registerHitTarget(ox, oy, proxy.r, 1+nInner+i);
      styledNode(ox, oy, proxy, "label");
    } else {
      NodeState[] ss = (slotStates != null && i < slotStates.length) ? slotStates[i] : null;
      if (ss == null) continue;
      float sc   = slotScale[i];
      float orb  = slotOrbitR[i];
      int   base = SLOT_BASE + i * MAX_SLOT_NODES;

      pushMatrix();
        translate(ox, oy);
        scale(sc);
        if (type == SLOT_CROSS) drawNCrossWithState(sn, ss, orb, base);
        else if (type == SLOT_SPOKE) drawNSpokeWithState(sn, ss, orb, base);
      popMatrix();

      // Correct hit targets to screen space
      int nodeCount = sn + 1;
      int startHit  = hitCount - nodeCount;
      for (int h = startHit; h < hitCount; h++) {
        int localJ = (int)(hitTargets[h][3]) - base;
        float lx, ly, lr;
        if (localJ == 0) {
          lx = 0; ly = 0; lr = ss[0].r;
        } else {
          NodeState ns = ss[localJ];
          lx =  orb * sin(ns.ang);
          ly = -orb * cos(ns.ang);
          lr = ns.r;
        }
        hitTargets[h][0] = inspectorCX + ox + lx * sc;
        hitTargets[h][1] = inspectorCY + oy + ly * sc;
        hitTargets[h][2] = lr * sc;
      }
    }
  }

  // ── Inner ring ───────────────────────────────────────────────────────────────
  styledOrbit(0, 0, twoInnerOrbitR, hub);

  for (int i = 0; i < nInner; i++) {
    NodeState ns = twoState[1+i];
    float sx =  twoInnerOrbitR * sin(ns.ang);
    float sy = -twoInnerOrbitR * cos(ns.ang);

    float dx =  sin(ns.ang);
    float dy = -cos(ns.ang);
    float px = -dy * off;
    float py =  dx * off;
    float gapC = hub.r + 4;
    float gapS = ns.r  + 4;

    registerHitTarget(sx, sy, ns.r, 1+i);
    styledNode(sx, sy, ns, "label");
    stroke(FG); strokeWeight(1.4);
    arrow(dx*gapC+px,    dy*gapC+py,    sx-dx*gapS+px, sy-dy*gapS+py, aHead);
    arrow(sx-dx*gapS-px, sy-dy*gapS-py, dx*gapC-px,    dy*gapC-py,    aHead);
  }

  // Hub last
  registerHitTarget(0, 0, hub.r, 0);
  styledNode(0, 0, hub, "label");
}
