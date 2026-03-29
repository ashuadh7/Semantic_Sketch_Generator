// ─── Global palette ──────────────────────────────────────────────────────────
int BG=255,FG=30,MUTED=120,BORDER=180;

final int SLOT_PLAIN=0,SLOT_CROSS=1,SLOT_SPOKE=2;

int nSpoke=4,nCross=5,nInner=0,nOuter=4;

int   appMode=0,activeFrame=2,numButtons=2;
float btnW,btnH=64,btnGap=12,btnTop=20,canvasY;

void setup(){
  size(1060,880);
  // Ensure data folder exists
  java.io.File dataDir = new java.io.File(sketchPath("data"));
  if (!dataDir.exists()) dataDir.mkdir();
  btnW=((width-SB_W)-(numButtons+1)*btnGap)/numButtons;
  canvasY=btnTop+btnH+btnGap+16;
  textFont(createFont("Helvetica",13));
  smooth(); initAllStates();
}

void draw(){
  background(BG); drawButtons();
  if(appMode==0){
    inspectorCX=(width-SB_W)/2.0;
    inspectorCY=canvasY+(height-20-canvasY)/2.0;
    resetHitTargets(512);
    pushMatrix(); translate(inspectorCX,inspectorCY); drawFramework(activeFrame); popMatrix();
    // After a swap, reselect the moved node by matching its NodeState reference
    if (pendingSelectNode != null) {
      for (int i = 0; i < hitCount; i++) {
        if (resolveHit((int)hitTargets[i][3]) == pendingSelectNode) {
          selectedNode = i; break;
        }
      }
      pendingSelectNode = null;
    }
    drawSelectionRing();
    drawHUD();
    sbResetZones(); drawSidebar();
  } else {
    float ch=height-canvasY-20;
    float canvasR=min(width,ch)*0.45;
    float ext=viewExtent(twoState!=null&&twoState.length>0?twoState[0]:null);
    float vs=(ext>0)?canvasR/ext:1.0;
    inspectorCX=width/2.0;
    inspectorCY=canvasY+ch/2.0;
    resetHitTargets(512);
    pushMatrix(); translate(inspectorCX,inspectorCY); scale(vs); drawFramework(activeFrame); popMatrix();
    // Correct hit targets from diagram-space to screen-space with viewScale applied
    for(int i=0;i<hitCount;i++){
      float wx=hitTargets[i][0]-inspectorCX, wy=hitTargets[i][1]-inspectorCY;
      hitTargets[i][0]=inspectorCX+wx*vs; hitTargets[i][1]=inspectorCY+wy*vs; hitTargets[i][2]*=vs;}
  }
  drawToast();
}

NodeState[]activeStates(){
  switch(activeFrame){case 0:return spokeState;case 1:return crossState;case 2:return twoState;}return null;}

void drawFramework(int id){
  switch(id){
    case 0:drawNSpoke(nSpoke);break;
    case 1:drawNCross(nCross);break;
    case 2:drawTwoLevel(nInner,nOuter);break;
    case 3:drawPlaceholder();break;}}

void mousePressed(){
  if(mouseX>=sbX()){if(appMode==0)sbMousePressed(mouseX,mouseY);return;}
  for(int i=0;i<numButtons;i++){
    float x=btnGap+i*(btnW+btnGap),y=btnTop;
    if(mouseX>x&&mouseX<x+btnW&&mouseY>y&&mouseY<y+btnH){
      if(i==0&&appMode!=0)resetViewCollapsed();
      if(i==1&&appMode!=1)collapseAllForView();
      appMode=i;return;}}
  if(appMode==0){
    if(editingLabel)commitLabelEdit(selectedNodeState());
    if(editingSubLabel)commitSubLabelEdit(selectedNodeState());
    if(editingFilename)commitFilenameEdit();
    selectedNode=pickNode(mouseX,mouseY);
  } else {
    int hit=pickNode(mouseX,mouseY);
    if(hit>=0){NodeState ns=resolveHit((int)hitTargets[hit][3]);
      if(ns!=null&&ns.isHub())ns.viewCollapsed=!ns.viewCollapsed;}}}

void mouseDragged(){if(appMode==0&&mouseX>=sbX())sbMouseDragged(mouseX,mouseY);}
void mouseReleased(){if(appMode==0)sbMouseReleased();}

void keyPressed(){
  if(appMode!=0)return;
  if(sbKeyPressed())return;
  if(key==TAB){selectedNode=(hitCount>0)?(selectedNode+1)%hitCount:-1;return;}
  if(key==ESC){key=0;selectedNode=-1;return;}

  NodeState ns=selectedNodeState();
  if(ns==null)return;

  // Determine if this node owns an orbit (is a hub of any kind)
  boolean ownsOrbit = ns.isHub() || (selectedOwner==null && selectedLocalIdx==0);

  switch(key){
    // [ ] resize selected node only
    case '[': ns.r=max(8,ns.r-2); ns.invalidateCache(); break;
    case ']': ns.r=ns.r+2;        ns.invalidateCache(); break;

    // { } proportional scale of sub-diagram (Shift+[/])
    case '{':
      if(ns.isHub()){ ns.r=max(8,ns.r*0.92); ns.invalidateCache(); ns.scaleProportional(0.92); }
      break;
    case '}':
      if(ns.isHub()){ ns.r=ns.r*1.08; ns.invalidateCache(); ns.scaleProportional(1.08); }
      break;

    // , . adjust orbit (hub only)
    case ',':
      if(ownsOrbit){
        if(ns.isHub()) ns.subOrbitR=max(20,ns.subOrbitR-5);
        else adjustHubOrbit(activeFrame,-5);
      } break;
    case '.':
      if(ownsOrbit){
        if(ns.isHub()) ns.subOrbitR+=5;
        else adjustHubOrbit(activeFrame, 5);
      } break;
  }
}

void drawButtons(){
  String[]modeLabels={"Edit","View"};
  for(int i=0;i<numButtons;i++){
    float x=btnGap+i*(btnW+btnGap),y=btnTop;boolean active=(appMode==i);
    fill(active?color(230,242,255):color(245));stroke(active?color(80,140,210):BORDER);strokeWeight(active?1.8:0.8);
    rect(x,y,btnW,btnH,10);
    fill(active?color(30,80,160):FG);noStroke();textSize(13);textAlign(CENTER,CENTER);text(modeLabels[i],x+btnW/2,y+btnH/2);}}

void resetViewCollapsed(){resetViewCollapsedRec(twoState);}
void resetViewCollapsedRec(NodeState[]arr){
  if(arr==null)return;
  for(NodeState ns:arr){ns.viewCollapsed=false;if(ns.isHub())resetViewCollapsedRec(ns.children);}}

void collapseAllForView(){collapseAllRec(twoState);}
void collapseAllRec(NodeState[]arr){
  if(arr==null)return;
  for(NodeState ns:arr){if(ns.isHub()){ns.viewCollapsed=true;collapseAllRec(ns.children);}}}

// Max screen-space radius from a node's centre given current viewCollapsed state
float viewExtent(NodeState ns){
  if(ns==null)return 0;
  if(!ns.isHub()||ns.viewCollapsed)return ns.r;
  float orbitR=ns.subOrbitR*ns.subScale, maxExt=ns.r;
  for(int i=1;i<ns.children.length;i++){
    NodeState c=ns.children[i];
    maxExt=max(maxExt,orbitR+(c.isHub()&&!c.viewCollapsed?viewExtent(c):c.r*ns.subScale));}
  return maxExt;}

// Blue tint overlay drawn on top of styledNode for any hub in View mode
void drawViewHubTint(float cx,float cy,NodeState ns){
  fill(color(80,140,210,50));noStroke();drawShape(cx,cy,ns);}

void drawEmptyState(){fill(MUTED);noStroke();textSize(13);textAlign(CENTER,CENTER);
  text("Nothing to display",(width-SB_W)/2.0,canvasY+(height-canvasY)/2.0);}
void drawPlaceholder(){fill(MUTED);noStroke();textSize(13);textAlign(CENTER,CENTER);
  text("This slot is empty — add your own framework here.",0,0);}

// ─── Styled draw helpers ──────────────────────────────────────────────────────
void styledNode(float x,float y,NodeState ns){
  int diameter=(int)(ns.r*2);boolean hasImg=(ns.img!=null);
  fill(255);stroke(BORDER);strokeWeight(1.5);drawShape(x,y,ns);
  if(hasImg){
    if(ns.cropToShape){ns.rebuildMask(diameter);
      if(ns.imgMasked!=null){imageMode(CENTER);image(ns.imgMasked,x,y,diameter,diameter);imageMode(CORNER);}}
    else{float asp=(float)ns.img.width/ns.img.height;
      float imgH=diameter/sqrt(asp*asp+1),imgW=imgH*asp;
      imageMode(CENTER);image(ns.img,x,y,imgW,imgH);imageMode(CORNER);}}
  color fc=color(red(ns.fillCol),green(ns.fillCol),blue(ns.fillCol),ns.alpha);
  fill(fc);noStroke();drawShape(x,y,ns);
  noFill();stroke(BORDER);strokeWeight(1.5);drawShape(x,y,ns);
  fill(FG);noStroke();
  if(hasImg){
    float lx=x+(ns.r+10)*sin(ns.labelAng), ly=y-(ns.r+10)*cos(ns.labelAng);
    float nx=sin(ns.labelAng), ny=-cos(ns.labelAng);
    int ha,va;
    if(abs(nx)>=abs(ny)){ha=nx>0?LEFT:RIGHT;va=CENTER;}
    else{ha=CENTER;va=ny<0?BOTTOM:TOP;}
    textSize(ns.labelSize);textAlign(ha,va);text(ns.label,lx,ly);
    if(!ns.subLabel.isEmpty()){
      fill(MUTED);textSize(max(9,ns.labelSize-2));
      float subLy=(va==BOTTOM)?ly-(ns.labelSize+2):(va==TOP)?ly+(ns.labelSize+2):ly+ns.labelSize/2+2;
      textAlign(ha,TOP);text(ns.subLabel,lx,subLy);
    }
  } else{textSize(ns.labelSize);textAlign(CENTER,CENTER);text(ns.label,x,ns.subLabel.isEmpty()?y:y-8);
    if(!ns.subLabel.isEmpty()){fill(MUTED);textSize(max(9,ns.labelSize-2));text(ns.subLabel,x,y+10);}}}

void drawShape(float x,float y,NodeState ns){
  if(ns.shapeType==SHAPE_RECT){rectMode(CENTER);rect(x,y,ns.r*2,ns.r*2,ns.r*0.3);rectMode(CORNER);}
  else if(ns.shapeType==SHAPE_DIAMOND){beginShape();vertex(x,y-ns.r);vertex(x+ns.r,y);vertex(x,y+ns.r);vertex(x-ns.r,y);endShape(CLOSE);}
  else ellipse(x,y,ns.r*2,ns.r*2);}

void styledOrbit(float x,float y,float r,NodeState hub){
  stroke(hub.orbitCol);strokeWeight(1);noFill();
  if(hub.orbitDashed)dashedCircle(x,y,r,7,5);else ellipse(x,y,r*2,r*2);}

void dashedCircle(float x,float y,float r,float dashLen,float gapLen){
  float step=dashLen/r+gapLen/r;noFill();
  for(float a=0;a<TWO_PI;a+=step)arc(x,y,r*2,r*2,a,min(a+dashLen/r,a+step-0.01));}

void arrow(float x1,float y1,float x2,float y2,float headSize){
  line(x1,y1,x2,y2);float ang=atan2(y2-y1,x2-x1);fill(FG);noStroke();
  triangle(x2,y2,x2-headSize*cos(ang-0.4),y2-headSize*sin(ang-0.4),
           x2-headSize*cos(ang+0.4),y2-headSize*sin(ang+0.4));stroke(FG);noFill();}

void labeledCircle(float x,float y,float r,String title,String sub){
  fill(245);stroke(BORDER);strokeWeight(1.5);ellipse(x,y,r*2,r*2);
  fill(FG);noStroke();textSize(13);textAlign(CENTER,CENTER);
  text(title,x,sub.isEmpty()?y:y-8);
  if(!sub.isEmpty()){fill(MUTED);textSize(11);text(sub,x,y+10);}}
