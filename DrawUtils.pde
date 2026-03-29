// ── DrawUtils ─────────────────────────────────────────────────────────────────
// Shared drawing primitives used by all diagram renderers and the sidebar.
// ─────────────────────────────────────────────────────────────────────────────

void styledNode(float x, float y, NodeState ns) {
  int diameter = (int)(ns.r*2); boolean hasImg = (ns.img != null);
  fill(255); stroke(BORDER); strokeWeight(1.5); drawShape(x, y, ns);
  if (hasImg) {
    if (ns.cropToShape) {
      ns.rebuildMask(diameter);
      if (ns.imgMasked != null) { imageMode(CENTER); image(ns.imgMasked, x, y, diameter, diameter); imageMode(CORNER); }
    } else {
      float asp = (float)ns.img.width / ns.img.height;
      float imgH = diameter / sqrt(asp*asp+1), imgW = imgH*asp;
      imageMode(CENTER); image(ns.img, x, y, imgW, imgH); imageMode(CORNER);
    }
  }
  color fc = color(red(ns.fillCol), green(ns.fillCol), blue(ns.fillCol), ns.alpha);
  fill(fc); noStroke(); drawShape(x, y, ns);
  noFill(); stroke(BORDER); strokeWeight(1.5); drawShape(x, y, ns);
  fill(FG); noStroke();
  if (hasImg) {
    float lx = x + (ns.r+10)*sin(ns.labelAng), ly = y - (ns.r+10)*cos(ns.labelAng);
    float nx = sin(ns.labelAng), ny = -cos(ns.labelAng);
    int ha, va;
    if (abs(nx) >= abs(ny)) { ha = nx>0 ? LEFT : RIGHT; va = CENTER; }
    else                    { ha = CENTER; va = ny<0 ? BOTTOM : TOP; }
    textSize(ns.labelSize); textAlign(ha, va); text(ns.label, lx, ly);
    if (!ns.subLabel.isEmpty()) {
      fill(MUTED); textSize(max(9, ns.labelSize-2));
      float subLy = (va==BOTTOM) ? ly-(ns.labelSize+2) : (va==TOP) ? ly+(ns.labelSize+2) : ly+ns.labelSize/2+2;
      textAlign(ha, TOP); text(ns.subLabel, lx, subLy);
    }
  } else {
    textSize(ns.labelSize); textAlign(CENTER, CENTER);
    text(ns.label, x, ns.subLabel.isEmpty() ? y : y-8);
    if (!ns.subLabel.isEmpty()) { fill(MUTED); textSize(max(9, ns.labelSize-2)); text(ns.subLabel, x, y+10); }
  }
}

void drawShape(float x, float y, NodeState ns) {
  if      (ns.shapeType == SHAPE_RECT)    { rectMode(CENTER); rect(x, y, ns.r*2, ns.r*2, ns.r*0.3); rectMode(CORNER); }
  else if (ns.shapeType == SHAPE_DIAMOND) { beginShape(); vertex(x,y-ns.r); vertex(x+ns.r,y); vertex(x,y+ns.r); vertex(x-ns.r,y); endShape(CLOSE); }
  else                                    { ellipse(x, y, ns.r*2, ns.r*2); }
}

void styledOrbit(float x, float y, float r, NodeState hub) {
  stroke(hub.orbitCol); strokeWeight(1); noFill();
  if (hub.orbitDashed) dashedCircle(x, y, r, 7, 5);
  else                 ellipse(x, y, r*2, r*2);
}

void dashedCircle(float x, float y, float r, float dashLen, float gapLen) {
  float step = dashLen/r + gapLen/r; noFill();
  for (float a = 0; a < TWO_PI; a += step)
    arc(x, y, r*2, r*2, a, min(a+dashLen/r, a+step-0.01));
}

void arrow(float x1, float y1, float x2, float y2, float headSize) {
  line(x1, y1, x2, y2);
  float ang = atan2(y2-y1, x2-x1); fill(FG); noStroke();
  triangle(x2, y2,
           x2 - headSize*cos(ang-0.4), y2 - headSize*sin(ang-0.4),
           x2 - headSize*cos(ang+0.4), y2 - headSize*sin(ang+0.4));
  stroke(FG); noFill();
}

void labeledCircle(float x, float y, float r, String title, String sub) {
  fill(245); stroke(BORDER); strokeWeight(1.5); ellipse(x, y, r*2, r*2);
  fill(FG); noStroke(); textSize(13); textAlign(CENTER, CENTER);
  text(title, x, sub.isEmpty() ? y : y-8);
  if (!sub.isEmpty()) { fill(MUTED); textSize(11); text(sub, x, y+10); }
}

void drawEmptyState() {
  fill(MUTED); noStroke(); textSize(13); textAlign(CENTER, CENTER);
  text("Nothing to display", (width-SB_W)/2.0, canvasY+(height-canvasY)/2.0);
}

void drawPlaceholder() {
  fill(MUTED); noStroke(); textSize(13); textAlign(CENTER, CENTER);
  text("This slot is empty — add your own framework here.", 0, 0);
}
