// ── Inspector + Sidebar ───────────────────────────────────────────────────────

int   selectedNode = -1;
float inspectorCX, inspectorCY;

// Reselect after swap: set to the moved node; cleared in draw() once found
NodeState pendingSelectNode = null;

float[][] hitTargets;
int       hitCount;

final int   SB_W    = 230;
final int   SB_PAD  = 14;
final color SB_BG   = color(248);
final color SB_LINE = color(210);

// ── Sidebar scroll ────────────────────────────────────────────────────────────
float sidebarScrollY  = 0;  // current scroll offset (pixels)
float sidebarContentH = 0;  // total content height, updated each draw

// ── Text editing ──────────────────────────────────────────────────────────────
boolean editingLabel    = false;
String  editBuffer      = "";

boolean editingSubLabel = false;
String  editSubBuffer   = "";

boolean editingFilename = false;
String  filenameBuffer  = "";

void activateLabelEdit(NodeState ns)    { editingSubLabel=false; editingLabel=true;    editBuffer=ns.label; }
void commitLabelEdit(NodeState ns)      { if(ns!=null&&editBuffer.length()>0) ns.label=editBuffer; editingLabel=false; }
void activateSubLabelEdit(NodeState ns) { editingLabel=false; editingSubLabel=true; editSubBuffer=ns.subLabel; }
void commitSubLabelEdit(NodeState ns)   { if(ns!=null) ns.subLabel=editSubBuffer; editingSubLabel=false; }

void activateFilenameEdit() { editingFilename=true; }
void commitFilenameEdit()   { editingFilename=false; }

// ── Hit registry ──────────────────────────────────────────────────────────────
void resetHitTargets(int max) { hitTargets=new float[max][4]; hitCount=0; }

void registerHitTarget(float wx, float wy, float r, int stateIdx) {
  if (hitCount>=hitTargets.length) return;
  hitTargets[hitCount][0]=inspectorCX+wx;
  hitTargets[hitCount][1]=inspectorCY+wy;
  hitTargets[hitCount][2]=r;
  hitTargets[hitCount][3]=stateIdx;
  hitCount++;
}

int selectedStateIdx() {
  if (selectedNode<0||selectedNode>=hitCount) return -1;
  return (int)hitTargets[selectedNode][3];
}

// Decode: fills selectedOwner + selectedLocalIdx as side effects
NodeState selectedOwner    = null;
int       selectedLocalIdx = -1;

NodeState selectedNodeState() {
  selectedOwner    = null;
  selectedLocalIdx = -1;
  int si = selectedStateIdx();
  if (si < 0) return null;

  if (si >= NESTED_BASE) {
    int rel      = si - NESTED_BASE;
    int ownerHit = rel / MAX_CHILDREN;
    int localIdx = rel % MAX_CHILDREN;
    NodeState owner = resolveHit((int)hitTargets[ownerHit][3]);
    if (owner==null||owner.children==null||localIdx>=owner.children.length) return null;
    selectedOwner    = owner;
    selectedLocalIdx = localIdx;
    return owner.children[localIdx];
  }

  NodeState[] states = activeStates();
  if (states==null||si>=states.length) return null;
  selectedLocalIdx = si;
  return states[si];
}

NodeState resolveHit(int si) {
  if (si >= NESTED_BASE) {
    int rel      = si - NESTED_BASE;
    int ownerHit = rel / MAX_CHILDREN;
    int localIdx = rel % MAX_CHILDREN;
    NodeState owner = resolveHit((int)hitTargets[ownerHit][3]);
    if (owner==null||owner.children==null||localIdx>=owner.children.length) return null;
    return owner.children[localIdx];
  }
  NodeState[] states = activeStates();
  if (states==null||si>=states.length) return null;
  return states[si];
}

// A node "acts as hub" if it owns children OR is index-0 of top-level array
boolean nodeActsAsHub(NodeState ns) {
  if (ns == null) return false;
  if (ns.isHub()) return true;
  // Top-level framework hub (index 0, no owner)
  return selectedOwner==null && selectedLocalIdx==0;
}

float currentOrbitR() {
  NodeState ns = selectedNodeState();
  if (ns==null) return 0;
  if (ns.isHub()) return ns.subOrbitR;   // sub-diagram hub controls its own ring
  // Top-level framework hub (plain, index 0)
  if (selectedOwner==null && selectedLocalIdx==0) {
    switch(activeFrame) {
      case 0: return spokeOrbitR;
      case 1: return crossOrbitR;
      case 2: return twoOuterOrbitR;
    }
  }
  return 0;
}

void drawSelectionRing() {
  if (selectedNode<0||selectedNode>=hitCount) return;
  float sx=hitTargets[selectedNode][0], sy=hitTargets[selectedNode][1], r=hitTargets[selectedNode][2];
  noFill(); stroke(60,120,220); strokeWeight(2.5);
  ellipse(sx,sy,(r+8)*2,(r+8)*2);
}

void drawHUD() {
  fill(MUTED); noStroke(); textSize(11); textAlign(CENTER,BOTTOM);
  if (selectedNodeState()==null) {
    text("Click a node  ·  [ ] radius  ·  { } scale sub-diagram  ·  , . orbit (hub)  ·  Tab  ·  Esc",
         (width-SB_W)/2.0, height-8); return;
  }
  if (editingLabel) { fill(color(30,80,180));
    text("Editing — Enter confirm  ·  Esc cancel",(width-SB_W)/2.0,height-8); return; }
  NodeState ns = selectedNodeState();
  float orb = currentOrbitR();
  fill(color(30,80,180));
  text("[*] "+ns.label+"  r="+int(ns.r)+(orb>0?"  orbit="+nf(orb,0,1):"")
    +"  [ ] node size"+(ns.isHub()?"  { } scale sub":"")
    +(orb>0?"  , . orbit":"")+"  Tab  Esc",
    (width-SB_W)/2.0, height-8);
}

int pickNode(float mx, float my) {
  for (int i=0;i<hitCount;i++) {
    float dx=mx-hitTargets[i][0], dy=my-hitTargets[i][1];
    if (dx*dx+dy*dy<=hitTargets[i][2]*hitTargets[i][2]) return i;
  }
  return -1;
}

// ── Sidebar ───────────────────────────────────────────────────────────────────
float sbX() { return width-SB_W; }

void drawSidebar() {
  float x=sbX();
  // Unscrolled background
  fill(SB_BG); noStroke(); rect(x,0,SB_W,height);
  stroke(SB_LINE); strokeWeight(1); line(x,0,x,height);

  // Clip to sidebar bounds and apply scroll offset
  clip((int)x, 0, SB_W, height);
  pushMatrix(); translate(0, -sidebarScrollY);

  NodeState ns = selectedNodeState();
  if (ns==null) {
    // Show save/load even with no selection
    float y = height - 174;
    sbDivider(y); y += 12;
    y = sbSectionLabel("Session", x, y);
    y = sbFilenameField(x, y);
    float bw=(SB_W-SB_PAD*2-4)/2.0;
    sbButton("Export PNG",   x+SB_PAD,      y, bw, 28, "SAVE_IMAGE", false);
    sbButton("Save session", x+SB_PAD+bw+4, y, bw, 28, "SAVE_STATE", false);
    y += 32;
    fill(MUTED); noStroke(); textSize(10); textAlign(LEFT, TOP);
    text("→ exports/", x+SB_PAD, y);
    text("→ states/", x+SB_PAD+bw+4, y);
    y += 16;
    sbButton("Load session", x+SB_PAD, y, SB_W-SB_PAD*2, 28, "LOAD_STATE", false);
    sidebarContentH = height;  // no-selection layout anchors near bottom — no scroll needed

    fill(MUTED); noStroke(); textSize(12); textAlign(CENTER,CENTER);
    text("Select a node\nto edit properties", x+SB_W/2.0, (height-200)/2.0);
    popMatrix(); noClip(); return;
  }

  boolean isNested     = (activeFrame == 2);
  boolean hasChildren  = ns.isHub();
  boolean isTopHub     = (selectedOwner==null && selectedLocalIdx==0);
  boolean isSatellite  = (selectedLocalIdx > 0);

  float y = 16;

  // Title
  fill(FG); noStroke(); textSize(13); textAlign(LEFT,TOP);
  text(ns.label, x+SB_PAD, y);
  fill(MUTED); textSize(10);
  text(isTopHub?"framework hub":hasChildren?"hub node":"satellite", x+SB_PAD, y+16);
  y+=38; sbDivider(y); y+=12;

  // Label
  y = sbSectionLabel("Label", x, y);
  boolean fa=editingLabel;
  fill(fa?color(230,240,255):color(238)); stroke(fa?color(80,140,210):color(200)); strokeWeight(fa?1.8:1);
  rect(x+SB_PAD,y,SB_W-SB_PAD*2,24,4);
  fill(FG); noStroke(); textSize(12); textAlign(LEFT,CENTER);
  text((fa?editBuffer:ns.label)+(fa&&frameCount%60<30?"|":""), x+SB_PAD+6, y+12);
  sbRegisterClick(x+SB_PAD,y,SB_W-SB_PAD*2,24,"LABEL_FIELD");
  y+=30;
  // Sub-label field
  boolean fs=editingSubLabel;
  fill(fs?color(230,240,255):color(242)); stroke(fs?color(80,140,210):color(210)); strokeWeight(fs?1.8:1);
  rect(x+SB_PAD,y,SB_W-SB_PAD*2,20,4);
  fill(ns.subLabel.isEmpty()&&!fs?MUTED:FG); noStroke(); textSize(10); textAlign(LEFT,CENTER);
  String subDisplay=fs?editSubBuffer:(ns.subLabel.isEmpty()?"sub-label (optional)":ns.subLabel);
  text(subDisplay+(fs&&frameCount%60<30?"|":""), x+SB_PAD+6, y+10);
  sbRegisterClick(x+SB_PAD,y,SB_W-SB_PAD*2,20,"SUBLABEL_FIELD");
  y+=28;
  y=sbSizeSlider("Font size", ns.labelSize, "LABEL_SIZE", x, y);
  sbDivider(y); y+=12;

  // Node appearance
  y = sbSectionLabel("Node", x, y);
  y = sbColorRow("Fill", ns.fillCol, ns.alpha, true, "NODE_COLOR", x, y);
  y = sbAlphaSlider("Fill alpha", ns.alpha, "NODE_ALPHA", x, y);
  y = sbShapeRow(ns.shapeType, x, y);
  y+=4; sbDivider(y); y+=12;

  // Image + Upload node
  y = sbSectionLabel("Image / Import", x, y);
  float previewSize=54;
  float previewX=x+SB_W/2.0-previewSize/2.0;
  if (ns.img!=null) {
    ns.rebuildMask((int)previewSize);
    if (ns.cropToShape&&ns.imgMasked!=null) { image(ns.imgMasked,previewX,y,previewSize,previewSize); }
    else { float asp=(float)ns.img.width/ns.img.height; float pH=previewSize/sqrt(asp*asp+1),pW=pH*asp;
           image(ns.img,previewX+(previewSize-pW)/2,y+(previewSize-pH)/2,pW,pH); }
    stroke(200); strokeWeight(1); noFill();
    if (ns.cropToShape) ellipse(previewX+previewSize/2,y+previewSize/2,previewSize,previewSize);
    else rect(previewX,y,previewSize,previewSize,4);
  } else {
    fill(230); stroke(200); strokeWeight(1); rect(previewX,y,previewSize,previewSize,6);
    fill(MUTED); noStroke(); textSize(10); textAlign(CENTER,CENTER);
    text("no image",previewX+previewSize/2,y+previewSize/2);
  }
  y+=previewSize+6;
  float bw3=(SB_W-SB_PAD*2-8)/3.0;
  sbButton("Add img",     x+SB_PAD,           y, bw3, 22, "IMG_ADD",    false);
  sbButton("Remove",      x+SB_PAD+bw3+4,     y, bw3, 22, "IMG_REMOVE", ns.img==null);
  sbButton("Import node", x+SB_PAD+(bw3+4)*2, y, bw3, 22, "IMPORT_NODE",!isNested);
  y+=28;
  y=sbToggle("Crop to shape",ns.cropToShape,"IMG_CROP",x,y,ns.img==null);
  if(ns.img!=null) y=sbLabelAngleSlider(ns.labelAng,x,y);
  y+=4; sbDivider(y); y+=12;

  // Orbit (hub only)
  float orb=currentOrbitR();
  boolean showOrbit=(hasChildren||isTopHub)&&orb>0;
  y=sbSectionLabel("Orbit",x,y,showOrbit);
  if (showOrbit) {
    y=sbColorRow("Color",ns.orbitCol,255,false,"ORBIT_COLOR",x,y);
    y=sbOrbitTypeRow(ns.orbitDashed,x,y);
    if (hasChildren) {
      fill(MUTED);noStroke();textSize(11);textAlign(LEFT,TOP);text("Satellite rotation",x+SB_PAD,y);y+=16;
      float bw2=(SB_W-SB_PAD*2-4)/2.0;
      sbReorderButton("CCW", false, x+SB_PAD,        y, bw2, 24, "SUB_ROT_CCW");
      sbReorderButton("CW",  true,  x+SB_PAD+bw2+4,  y, bw2, 24, "SUB_ROT_CW");
      y+=32;
    }
  } else { fill(MUTED);noStroke();textSize(11);textAlign(LEFT,TOP); text("(select hub)",x+SB_PAD,y); y+=18; }
  y+=4; sbDivider(y); y+=12;

  // Reorder (any satellite with siblings, all frames)
  if (isSatellite) {
    int numSib = (selectedOwner != null) ? selectedOwner.numSatellites()
                 : (activeStates() != null ? activeStates().length - 1 : 0);
    if (numSib >= 2) {
      y = sbSectionLabel("Reorder", x, y);
      float bw2 = (SB_W - SB_PAD*2 - 4) / 2.0;
      sbReorderButton("CCW", false, x+SB_PAD,        y, bw2, 26, "SWAP_PREV");
      sbReorderButton("CW",  true,  x+SB_PAD+bw2+4,  y, bw2, 26, "SWAP_NEXT");
      y += 34; sbDivider(y); y += 12;
    }
  }

  // Nesting (nested tab only)
  if (isNested) {
    y=sbSectionLabel("Nesting",x,y);

    if (!hasChildren) {
      // Plain node — offer to add first satellite
      fill(MUTED); noStroke(); textSize(11); textAlign(LEFT,TOP);
      text(isTopHub?"Add satellites:":"Expand this node:", x+SB_PAD, y); y+=16;
      float bw2=(SB_W-SB_PAD*2-4)/2.0;
      sbButton("+ Spoke",x+SB_PAD,       y,bw2,24,"PROMOTE_CROSS",false);
      sbButton("+ Radial",x+SB_PAD+bw2+4,y,bw2,24,"PROMOTE_SPOKE",false);
      y+=32;
    } else {
      // Already has satellites
      fill(MUTED); noStroke(); textSize(11); textAlign(LEFT,TOP);
      text("Type: "+(ns.subType==SLOT_CROSS?"Spoke":"Radial")
           +"   "+ns.numSatellites()+" satellite"+(ns.numSatellites()!=1?"s":""),
           x+SB_PAD, y); y+=16;
      float bw2=(SB_W-SB_PAD*2-8)/3.0;
      sbButton("− sat",   x+SB_PAD,           y,bw2,24,"SAT_REMOVE",ns.numSatellites()<=1);
      sbButton("+ sat",   x+SB_PAD+bw2+4,     y,bw2,24,"SAT_ADD",   false);
      sbButton("Flatten", x+SB_PAD+(bw2+4)*2, y,bw2,24,"DEMOTE",    false);
      y+=32;
      float bw22=(SB_W-SB_PAD*2-4)/2.0;
      sbButton("> Spoke", x+SB_PAD,        y,bw22,22,"SWITCH_CROSS",ns.subType==SLOT_CROSS);
      sbButton("> Radial",x+SB_PAD+bw22+4,y,bw22,22,"SWITCH_SPOKE",ns.subType==SLOT_SPOKE);
      y+=30;
    }
    if (isSatellite) {
      sbButton("Delete this node",x+SB_PAD,y,SB_W-SB_PAD*2,24,"DELETE_NODE",false);
      y+=32;
    }
    sbDivider(y); y+=12;
  }

  // Save / Load
  y=sbSectionLabel("Session",x,y);
  y=sbFilenameField(x,y);
  float bw2=(SB_W-SB_PAD*2-4)/2.0;
  sbButton("Export PNG",   x+SB_PAD,      y, bw2, 26, "SAVE_IMAGE", false);
  sbButton("Save session", x+SB_PAD+bw2+4,y, bw2, 26, "SAVE_STATE", false);
  y+=30;
  fill(MUTED); noStroke(); textSize(10); textAlign(LEFT, TOP);
  text("→ exports/", x+SB_PAD, y);
  text("→ states/", x+SB_PAD+bw2+4, y);
  y+=16;
  sbButton("Load session",x+SB_PAD,y,SB_W-SB_PAD*2,26,"LOAD_STATE",false);
  y+=34;

  sidebarContentH = y;  // record total content height for scroll clamping
  popMatrix(); noClip();

  // Draw scroll indicator if content overflows
  if (sidebarContentH > height) {
    float trackH = height;
    float thumbH = max(24, trackH * (height / sidebarContentH));
    float thumbY = (sidebarScrollY / (sidebarContentH - height)) * (trackH - thumbH);
    noStroke(); fill(180, 180, 180, 160);
    rect(x+SB_W-5, thumbY, 4, thumbH, 2);
  }
}

// ── Filename field helper ─────────────────────────────────────────────────────
float sbFilenameField(float x, float y) {
  fill(MUTED); noStroke(); textSize(11); textAlign(LEFT, TOP);
  text("Filename (optional)", x+SB_PAD, y); y += 14;
  boolean fe = editingFilename;
  fill(fe ? color(230,240,255) : color(238));
  stroke(fe ? color(80,140,210) : color(200));
  strokeWeight(fe ? 1.8 : 1);
  rect(x+SB_PAD, y, SB_W-SB_PAD*2, 24, 4);
  String display = filenameBuffer.length()>0 ? filenameBuffer : "auto timestamp";
  if (fe) display = filenameBuffer;
  fill(filenameBuffer.length()==0 && !fe ? MUTED : FG);
  noStroke(); textSize(12); textAlign(LEFT, CENTER);
  text(display + (fe && frameCount%60<30 ? "|" : ""), x+SB_PAD+6, y+12);
  sbRegisterClick(x+SB_PAD, y, SB_W-SB_PAD*2, 24, "FILENAME_FIELD");
  y += 32;
  return y;
}

// ── Sidebar helpers ───────────────────────────────────────────────────────────
void sbDivider(float y){stroke(SB_LINE);strokeWeight(1);line(sbX(),y,sbX()+SB_W,y);}

float sbSectionLabel(String l,float x,float y){return sbSectionLabel(l,x,y,true);}
float sbSectionLabel(String l,float x,float y,boolean active){
  fill(active?color(80,130,200):MUTED);noStroke();textSize(10);textAlign(LEFT,TOP);
  text(l.toUpperCase(),x+SB_PAD,y);return y+18;}

// hasNoFill=true adds a white swatch and a no-fill (slash) swatch.
// alpha is needed to detect whether no-fill is currently active.
float sbColorRow(String label,color current,int alpha,boolean hasNoFill,String tag,float x,float y){
  fill(MUTED);noStroke();textSize(11);textAlign(LEFT,TOP);text(label,x+SB_PAD,y);
  color[]cols={color(245),color(200,70,70),color(160),color(70,170,100)};  // default, red, grey, green
  String[]suffixes={"_W","_0","_1","_2"};
  float sw=20,gap=5;
  int total=hasNoFill?5:4;
  float sx0=x+SB_W-SB_PAD-(sw+gap)*total+gap;
  int off=0;
  if(hasNoFill){
    // No-fill swatch: white background + red diagonal slash
    boolean sel=(alpha==0);
    fill(255);stroke(sel?color(40,80,180):color(180));strokeWeight(sel?2.5:1);
    rect(sx0,y-1,sw,sw,4);
    stroke(color(200,50,50));strokeWeight(1.5);
    line(sx0+3,y+sw-4,sx0+sw-3,y);
    sbRegisterClick(sx0,y-1,sw,sw,tag+"_X");
    off=1;
  }
  for(int i=0;i<4;i++){
    float sx=sx0+(off+i)*(sw+gap);
    boolean sel=(alpha>0)&&(int)red(current)==(int)red(cols[i])&&(int)green(current)==(int)green(cols[i])&&(int)blue(current)==(int)blue(cols[i]);
    fill(cols[i]);stroke(sel?color(40,80,180):color(180));strokeWeight(sel?2.5:1);
    rect(sx,y-1,sw,sw,4);sbRegisterClick(sx,y-1,sw,sw,tag+suffixes[i]);
  }
  return y+sw+6;}

float sbAlphaSlider(String label,int current,String tag,float x,float y){
  fill(MUTED);noStroke();textSize(11);textAlign(LEFT,TOP);text(label,x+SB_PAD,y);
  fill(FG);textAlign(RIGHT,TOP);text(current,x+SB_W-SB_PAD,y);y+=16;
  float tx=x+SB_PAD,tw=SB_W-SB_PAD*2,th=6;
  fill(210);noStroke();rect(tx,y,tw,th,3);fill(100,140,220);rect(tx,y,tw*(current/255.0),th,3);
  fill(255);stroke(150);strokeWeight(1.5);ellipse(tx+tw*(current/255.0),y+th/2,12,12);
  sbRegisterClick(tx,y-16,tw,th+20,tag);return y+th+12;}

float sbSizeSlider(String label,int current,String tag,float x,float y){
  final int SMIN=8,SMAX=28;
  fill(MUTED);noStroke();textSize(11);textAlign(LEFT,TOP);text(label,x+SB_PAD,y);
  fill(FG);textAlign(RIGHT,TOP);text(current+"px",x+SB_W-SB_PAD,y);y+=16;
  float tx=x+SB_PAD,tw=SB_W-SB_PAD*2,th=6;
  fill(210);noStroke();rect(tx,y,tw,th,3);
  fill(100,140,220);rect(tx,y,tw*((current-SMIN)/(float)(SMAX-SMIN)),th,3);
  fill(255);stroke(150);strokeWeight(1.5);ellipse(tx+tw*((current-SMIN)/(float)(SMAX-SMIN)),y+th/2,12,12);
  sbRegisterClick(tx,y-16,tw,th+20,tag);return y+th+12;}

float sbShapeRow(int current,float x,float y){
  fill(MUTED);noStroke();textSize(11);textAlign(LEFT,TOP);text("Shape",x+SB_PAD,y);y+=16;
  int[]types={SHAPE_CIRCLE,SHAPE_RECT,SHAPE_DIAMOND};
  float bw=(SB_W-SB_PAD*2-8)/3.0;
  for(int i=0;i<3;i++){
    float bx=x+SB_PAD+i*(bw+4);
    boolean sel=(current==types[i]);
    // Button background
    fill(sel?color(210,230,255):color(235));
    stroke(sel?color(80,140,210):color(200));strokeWeight(sel?1.8:1);
    rect(bx,y,bw,26,5);
    // Draw shape icon programmatically — no Unicode needed
    color ic=sel?color(30,80,160):color(80);
    fill(ic);stroke(ic);strokeWeight(1);
    float cx=bx+bw/2, cy=y+13, r=6;
    if(i==0){ // Circle
      ellipse(cx,cy,r*2,r*2);
    } else if(i==1){ // Rectangle
      noStroke();rect(cx-r,cy-r*0.55,r*2,r*1.1,1);
    } else { // Diamond
      beginShape();vertex(cx,cy-r);vertex(cx+r,cy);vertex(cx,cy+r);vertex(cx-r,cy);endShape(CLOSE);
    }
    sbRegisterClick(bx,y,bw,26,"SHAPE_"+i);
  }
  return y+32;}

// Circular drag slider for label angle (image nodes only).
// Drag the handle around the ring to set the label's position relative to the node.
float labelSliderCX=0, labelSliderCY=0;  // stored each draw for use in drag handler
float sbLabelAngleSlider(float ang, float x, float y) {
  fill(MUTED); noStroke(); textSize(11); textAlign(LEFT,TOP);
  text("Label angle", x+SB_PAD, y); y+=14;
  float outerR=26, nodeR=9;
  float cx=x+SB_W/2.0, cy=y+outerR;
  labelSliderCX=cx; labelSliderCY=cy-sidebarScrollY;  // screen-space y for drag handler
  // Outer ring (dashed, like an orbit)
  noFill(); stroke(200); strokeWeight(1);
  dashedCircle(cx, cy, outerR, 5, 4);
  // Centre node representation
  fill(230); stroke(BORDER); strokeWeight(1);
  ellipse(cx, cy, nodeR*2, nodeR*2);
  // Spoke line from centre to handle
  float hx=cx+outerR*sin(ang), hy=cy-outerR*cos(ang);
  stroke(100,140,220); strokeWeight(1.5);
  line(cx, cy, hx, hy);
  // Handle
  fill(80,120,200); noStroke();
  ellipse(hx, hy, 10, 10);
  // "A" on handle to indicate label
  fill(255); noStroke(); textSize(7); textAlign(CENTER,CENTER);
  text("A", hx, hy);
  // Drag zone
  sbRegisterClick(cx-outerR, cy-outerR, outerR*2, outerR*2, "LABEL_ANGLE");
  return cy+outerR+8;
}

float sbOrbitTypeRow(boolean dashed,float x,float y){
  fill(MUTED);noStroke();textSize(11);textAlign(LEFT,TOP);text("Orbit line",x+SB_PAD,y);y+=16;
  String[]lbs={"- - -","Solid"};boolean[]vals={true,false};float bw=(SB_W-SB_PAD*2-4)/2.0;
  for(int i=0;i<2;i++){float bx=x+SB_PAD+i*(bw+4);boolean sel=(dashed==vals[i]);
    fill(sel?color(210,230,255):color(235));stroke(sel?color(80,140,210):color(200));strokeWeight(sel?1.8:1);
    rect(bx,y,bw,26,5);fill(sel?color(30,80,160):FG);noStroke();textSize(11);textAlign(CENTER,CENTER);
    text(lbs[i],bx+bw/2,y+13);sbRegisterClick(bx,y,bw,26,"ORBIT_TYPE_"+i);}
  return y+32;}

// Draws a button with a programmatic arc-arrow icon + "CW" or "CCW" label.
// clockwise=true → arrowhead at the end of the arc (CW direction)
// clockwise=false → arrowhead at the start of the arc (CCW direction)
void sbReorderButton(String label, boolean clockwise, float bx, float by, float bw, float bh, String tag) {
  fill(color(235)); stroke(color(190)); strokeWeight(1);
  rect(bx, by, bw, bh, 4);
  // Arc: 270° opening to the right, centered in left portion of button
  float cx=bx+15, cy=by+bh/2, r=6;
  float startA=-HALF_PI-QUARTER_PI, stopA=HALF_PI+QUARTER_PI;
  noFill(); stroke(color(70)); strokeWeight(1.5);
  arc(cx, cy, r*2, r*2, startA, stopA);
  // Arrowhead triangle at appropriate end
  float hx, hy, hdir;
  if (clockwise) { hx=cx+r*cos(stopA);  hy=cy+r*sin(stopA);  hdir=stopA+HALF_PI;  }
  else           { hx=cx+r*cos(startA); hy=cy+r*sin(startA); hdir=startA-HALF_PI; }
  fill(color(70)); noStroke();
  pushMatrix(); translate(hx,hy); rotate(hdir);
  triangle(0,-3.5,-2.5,2,2.5,2);
  popMatrix();
  // Label text
  fill(color(70)); noStroke(); textSize(11); textAlign(LEFT,CENTER);
  text(label, bx+28, by+bh/2);
  sbRegisterClick(bx, by, bw, bh, tag);
}

float sbToggle(String label,boolean state,String tag,float x,float y,boolean disabled){
  fill(disabled?color(200):MUTED);noStroke();textSize(11);textAlign(LEFT,CENTER);text(label,x+SB_PAD,y+10);
  float tx=x+SB_W-SB_PAD-36,ty=y+2;
  fill(disabled?color(220):(state?color(80,160,100):color(190)));noStroke();rect(tx,ty,36,16,8);
  fill(255);noStroke();ellipse(state?tx+26:tx+10,ty+8,12,12);
  if(!disabled)sbRegisterClick(tx,ty,36,16,tag);return y+26;}

void sbButton(String label,float x,float y,float w,float h,String tag,boolean disabled){
  fill(disabled?color(225):color(235));stroke(disabled?color(210):color(190));strokeWeight(1);
  rect(x,y,w,h,4);fill(disabled?color(180):FG);noStroke();textSize(11);textAlign(CENTER,CENTER);
  text(label,x+w/2,y+h/2);if(!disabled)sbRegisterClick(x,y,w,h,tag);}

// ── Click zones ───────────────────────────────────────────────────────────────
final int MAX_SB_ZONES=120;
float[][]sbZones=new float[MAX_SB_ZONES][4];
String[]sbZoneTags=new String[MAX_SB_ZONES];
int sbZoneCount=0;
void sbResetZones(){sbZoneCount=0;}
void sbRegisterClick(float x,float y,float w,float h,String tag){
  if(sbZoneCount>=MAX_SB_ZONES)return;
  sbZones[sbZoneCount][0]=x;sbZones[sbZoneCount][1]=y;
  sbZones[sbZoneCount][2]=w;sbZones[sbZoneCount][3]=h;
  sbZoneTags[sbZoneCount]=tag;sbZoneCount++;}
String sbPickZone(float mx,float my){
  for(int i=0;i<sbZoneCount;i++)
    if(mx>=sbZones[i][0]&&mx<=sbZones[i][0]+sbZones[i][2]&&
       my>=sbZones[i][1]&&my<=sbZones[i][1]+sbZones[i][3])return sbZoneTags[i];
  return null;}

void sbHandleClick(String tag,float mx,float my){
  if(tag==null)return;
  NodeState ns=selectedNodeState();
  // cols matches sbColorRow order: white, red, grey, green (indices W,0,1,2)
  color[]cols={color(255),color(200,70,70),color(160),color(70,170,100)};

  // Session — no node needed
  if(tag.equals("FILENAME_FIELD")){activateFilenameEdit();return;}
  if(tag.equals("SAVE_IMAGE")){commitFilenameEdit();saveCanvasImage(filenameBuffer);return;}
  if(tag.equals("SAVE_STATE")){commitFilenameEdit();saveState(filenameBuffer);return;}
  if(tag.equals("LOAD_STATE")){selectInput("Load state file","stateFileSelected");return;}

  if(ns==null)return;
  if(tag.equals("LABEL_FIELD"))          activateLabelEdit(ns);
  else if(tag.equals("SUBLABEL_FIELD"))  activateSubLabelEdit(ns);
  else if(tag.startsWith("NODE_COLOR_")) {
    char c=tag.charAt(tag.length()-1);
    if     (c=='X')               { ns.alpha=0; }                           // no-fill
    else if(c=='W')               { ns.fillCol=cols[0]; ns.alpha=255; }     // default
    else                          { ns.fillCol=cols[int(c)-48+1]; ns.alpha=255; } // red/grey/green (+1 offset for white)
  }
  else if(tag.startsWith("ORBIT_COLOR_")) {
    char c=tag.charAt(tag.length()-1);
    if (c=='W') ns.orbitCol=cols[0];
    else        ns.orbitCol=cols[int(c)-48+1];
  }
  else if(tag.startsWith("SHAPE_"))      { ns.shapeType=int(tag.charAt(tag.length()-1))-48; ns.invalidateCache(); }
  else if(tag.equals("LABEL_ANGLE")) { float dx=mx-labelSliderCX,dy=my-labelSliderCY; if(dx*dx+dy*dy>9) ns.labelAng=atan2(dx,-dy); }
  else if(tag.startsWith("ORBIT_TYPE_")) ns.orbitDashed=(int(tag.charAt(tag.length()-1))-48==0);
  else if(tag.equals("NODE_ALPHA"))      { float tx=sbX()+SB_PAD,tw=SB_W-SB_PAD*2; ns.alpha=(int)constrain(map(mx,tx,tx+tw,0,255),0,255); }
  else if(tag.equals("LABEL_SIZE"))      { float tx=sbX()+SB_PAD,tw=SB_W-SB_PAD*2; ns.labelSize=(int)constrain(map(mx,tx,tx+tw,8,28),8,28); }
  else if(tag.equals("IMG_ADD"))         { pendingImageNode=ns; selectInput("Select image","imageSelected"); }
  else if(tag.equals("IMG_REMOVE"))      { ns.img=null; ns.invalidateCache(); }
  else if(tag.equals("IMG_CROP"))        { ns.cropToShape=!ns.cropToShape; ns.invalidateCache(); }
  else if(tag.equals("IMPORT_NODE"))     { selectInput("Select state file to import","importNodeSelected"); }
  else if(tag.equals("PROMOTE_CROSS"))   ns.promote(SLOT_CROSS,3);
  else if(tag.equals("PROMOTE_SPOKE"))   ns.promote(SLOT_SPOKE,3);
  else if(tag.equals("DEMOTE"))          ns.demote();
  else if(tag.equals("SAT_ADD"))         ns.addSatellite();
  else if(tag.equals("SAT_REMOVE"))      ns.removeSatellite(ns.numSatellites());
  else if(tag.equals("SWITCH_CROSS"))    ns.subType=SLOT_CROSS;
  else if(tag.equals("SWITCH_SPOKE"))    ns.subType=SLOT_SPOKE;
  else if(tag.equals("DELETE_NODE"))     deleteSatellite();
  else if(tag.equals("SWAP_PREV"))       swapSatellite(-1);
  else if(tag.equals("SWAP_NEXT"))       swapSatellite(+1);
  else if(tag.equals("SUB_ROT_CCW"))     ns.subAngOffset -= PI/12;
  else if(tag.equals("SUB_ROT_CW"))      ns.subAngOffset += PI/12;
}

void deleteSatellite(){
  selectedNodeState();
  if(selectedLocalIdx<=0)return;
  if(selectedOwner!=null){ selectedOwner.removeSatellite(selectedLocalIdx); }
  else {
    NodeState[]states=activeStates(); if(states==null)return;
    NodeState[]next=new NodeState[states.length-1]; int k=0;
    for(int i=0;i<states.length;i++) if(i!=selectedLocalIdx) next[k++]=states[i];
    setActiveStates(next);
  }
  selectedNode=-1;
}

// ── Satellite reordering ──────────────────────────────────────────────────────
// direction < 0 = swap with previous slot (wraps), direction > 0 = swap with next slot (wraps)
// Hub nodes carry their entire sub-diagram because we swap NodeState references.
void swapSatellite(int direction) {
  selectedNodeState(); // refresh selectedOwner and selectedLocalIdx
  if (selectedLocalIdx <= 0) return;

  NodeState movedNode;

  if (selectedOwner != null) {
    // Satellite inside a hub's children[] (nested, or Frame-2 outer ring)
    int n = selectedOwner.numSatellites();
    if (n <= 1) return;
    int cur  = selectedLocalIdx;
    int next = (direction < 0) ? (cur == 1 ? n : cur-1)
                                : (cur == n ? 1 : cur+1);
    NodeState tmp = selectedOwner.children[cur];
    selectedOwner.children[cur]  = selectedOwner.children[next];
    selectedOwner.children[next] = tmp;
    selectedOwner.recomputeAngles();
    movedNode = selectedOwner.children[next];
  } else {
    // Top-level satellite in Frame 0 or 1
    NodeState[] states = activeStates();
    if (states == null) return;
    int n = states.length - 1;
    if (n <= 1) return;
    int cur  = selectedLocalIdx;
    int next = (direction < 0) ? (cur == 1 ? n : cur-1)
                                : (cur == n ? 1 : cur+1);
    NodeState tmp = states[cur];
    states[cur]  = states[next];
    states[next] = tmp;
    recomputeTopLevelAngles(states);
    movedNode = states[next];
  }

  pendingSelectNode = movedNode;
}

// Recalculate fixed angles for top-level spoke (frame 0) or cross (frame 1) arrays.
void recomputeTopLevelAngles(NodeState[] states) {
  int n = states.length - 1;
  for (int i = 0; i < n; i++) {
    states[i+1].ang = (activeFrame == 0)
      ? radians(180 + i * (360.0/n))
      : radians(i * (360.0/n));
  }
}

boolean sbDragging=false; String sbDragTag=null;
void sbMousePressed(float mx,float my){String tag=sbPickZone(mx,my);sbDragTag=tag;sbDragging=true;sbHandleClick(tag,mx,my);}
void sbMouseDragged(float mx,float my){
  if(!sbDragging||sbDragTag==null)return;
  NodeState ns=selectedNodeState(); if(ns==null)return;
  if(sbDragTag.equals("NODE_ALPHA")){
    float tx=sbX()+SB_PAD,tw=SB_W-SB_PAD*2;
    ns.alpha=(int)constrain(map(mx,tx,tx+tw,0,255),0,255);
  } else if(sbDragTag.equals("LABEL_SIZE")){
    float tx=sbX()+SB_PAD,tw=SB_W-SB_PAD*2;
    ns.labelSize=(int)constrain(map(mx,tx,tx+tw,8,28),8,28);
  } else if(sbDragTag.equals("LABEL_ANGLE")){
    float dx=mx-labelSliderCX, dy=my-labelSliderCY;
    if(dx*dx+dy*dy>9) ns.labelAng=atan2(dx,-dy);
  }
}
void sbMouseReleased(){sbDragging=false;sbDragTag=null;}

boolean sbKeyPressed(){
  if(editingFilename){
    if(key==ENTER||key==RETURN){commitFilenameEdit();return true;}
    if(key==ESC){editingFilename=false;key=0;return true;}
    if(key==BACKSPACE){if(filenameBuffer.length()>0)filenameBuffer=filenameBuffer.substring(0,filenameBuffer.length()-1);return true;}
    if(key>=32&&key<127){filenameBuffer+=key;return true;}
    return true;
  }
  NodeState ns=selectedNodeState();
  if(editingSubLabel){
    if(key==ENTER||key==RETURN){commitSubLabelEdit(ns);return true;}
    if(key==ESC){editingSubLabel=false;key=0;return true;}
    if(key==BACKSPACE){if(editSubBuffer.length()>0)editSubBuffer=editSubBuffer.substring(0,editSubBuffer.length()-1);return true;}
    if(key>=32&&key<127){editSubBuffer+=key;return true;}
    return true;
  }
  if(!editingLabel)return false;
  if(key==ENTER||key==RETURN){commitLabelEdit(ns);return true;}
  if(key==ESC){editingLabel=false;key=0;return true;}
  if(key==BACKSPACE){if(editBuffer.length()>0)editBuffer=editBuffer.substring(0,editBuffer.length()-1);return true;}
  if(key>=32&&key<127){editBuffer+=key;return true;}
  return true;
}
