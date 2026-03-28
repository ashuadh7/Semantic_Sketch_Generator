// ─── Global palette ──────────────────────────────────────────────────────────
int BG=255,FG=30,MUTED=120,BORDER=180;

final int SLOT_PLAIN=0,SLOT_CROSS=1,SLOT_SPOKE=2;

int nSpoke=4,nCross=5,nInner=0,nOuter=4;

int   activeFrame=-1,numButtons=4;
float btnW,btnH=64,btnGap=12,btnTop=20,canvasY;

String[]btnLabels={"n-spoke radial","n-node cross","nested level","+ add framework"};

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
  inspectorCX=(width-SB_W)/2.0;
  inspectorCY=canvasY+(height-20-canvasY)/2.0;
  if(activeFrame>=0){
    resetHitTargets(512);
    pushMatrix(); translate(inspectorCX,inspectorCY); drawFramework(activeFrame); popMatrix();
    drawSelectionRing();
  } else drawEmptyState();
  drawHUD();
  sbResetZones(); drawSidebar();
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
  if(mouseX>=sbX()){sbMousePressed(mouseX,mouseY);return;}
  for(int i=0;i<numButtons;i++){
    float x=btnGap+i*(btnW+btnGap),y=btnTop;
    if(mouseX>x&&mouseX<x+btnW&&mouseY>y&&mouseY<y+btnH){
      if(activeFrame!=i){selectedNode=-1;editingLabel=false;}
      activeFrame=(activeFrame==i)?-1:i;return;}}
  if(activeFrame>=0){
    if(editingLabel)commitLabelEdit(selectedNodeState());
    if(editingFilename)commitFilenameEdit();
    selectedNode=pickNode(mouseX,mouseY);}}

void mouseDragged(){if(mouseX>=sbX())sbMouseDragged(mouseX,mouseY);}
void mouseReleased(){sbMouseReleased();}

void keyPressed(){
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
  String[]meta={"n="+nSpoke+" spokes","n="+nCross+" nodes",
                  twoState!=null&&twoState[0].isHub()?
                    twoState[0].numSatellites()+" satellites":"empty — click to build",
                  "your next diagram"};
  for(int i=0;i<numButtons;i++){
    float x=btnGap+i*(btnW+btnGap),y=btnTop;boolean active=(activeFrame==i);
    fill(active?color(230,242,255):color(245));stroke(active?color(80,140,210):BORDER);strokeWeight(active?1.8:0.8);
    rect(x,y,btnW,btnH,10);
    fill(active?color(30,80,160):FG);noStroke();textSize(13);textAlign(LEFT,TOP);text(btnLabels[i],x+12,y+12);
    fill(active?color(80,130,200):MUTED);textSize(11);text(meta[i],x+12,y+32);}}

void drawEmptyState(){fill(MUTED);noStroke();textSize(13);textAlign(CENTER,CENTER);
  text("Select a framework above to preview it",(width-SB_W)/2.0,canvasY+(height-canvasY)/2.0);}
void drawPlaceholder(){fill(MUTED);noStroke();textSize(13);textAlign(CENTER,CENTER);
  text("This slot is empty — add your own framework here.",0,0);}

// ─── Styled draw helpers ──────────────────────────────────────────────────────
void styledNode(float x,float y,NodeState ns,String sub){
  int diameter=(int)(ns.r*2);boolean hasImg=(ns.img!=null);
  fill(255);stroke(BORDER);strokeWeight(1.5);drawShape(x,y,ns);
  if(hasImg){
    if(ns.cropToShape){ns.rebuildMask(diameter);
      if(ns.imgMasked!=null){imageMode(CENTER);image(ns.imgMasked,x,y,diameter,diameter);imageMode(CORNER);}}
    else{float asp=(float)ns.img.width/ns.img.height;
      float imgH=diameter/sqrt(asp*asp+1),imgW=imgH*asp;
      imageMode(CENTER);image(ns.img,x,y,imgW,imgH);imageMode(CORNER);}}
  color fc=color(red(ns.fillCol),green(ns.fillCol),blue(ns.fillCol),hasImg?ns.alpha:255);
  fill(fc);noStroke();drawShape(x,y,ns);
  noFill();stroke(BORDER);strokeWeight(1.5);drawShape(x,y,ns);
  fill(FG);noStroke();
  if(hasImg){textSize(12);textAlign(CENTER,TOP);text(ns.label,x,y+ns.r+4);}
  else{textSize(13);textAlign(CENTER,CENTER);text(ns.label,x,sub.isEmpty()?y:y-8);
    if(!sub.isEmpty()){fill(MUTED);textSize(11);text(sub,x,y+10);}}}

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
