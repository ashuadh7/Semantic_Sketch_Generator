// ─── Global palette ──────────────────────────────────────────────────────────
int BG=255,FG=30,MUTED=120,BORDER=180;

final int SLOT_PLAIN=0,SLOT_CROSS=1,SLOT_SPOKE=2;

int nSpoke=4,nCross=5,nInner=0,nOuter=4;

int   appMode=0,activeFrame=2,numButtons=2;
float btnW,btnH=64,btnGap=12,btnTop=20,canvasY;

// ── View mode state ───────────────────────────────────────────────────────────
float viewZoom=1.0, viewPanX=0, viewPanY=0;
boolean viewIsDragging=false;
float   viewDragStartX, viewDragStartY;

// ── Edit mode pan/zoom ────────────────────────────────────────────────────────
float editZoom=1.0, editPanX=0, editPanY=0;
boolean editIsPanning=false;

void setup(){
  size(1060,880);
  // Ensure data folder exists
  java.io.File dataDir = new java.io.File(sketchPath("data"));
  if (!dataDir.exists()) dataDir.mkdir();
  btnW=120;
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
    clip(0,(int)canvasY,width-SB_W,(int)(height-20-canvasY));
    pushMatrix(); translate(inspectorCX+editPanX,inspectorCY+editPanY); scale(editZoom); drawFramework(activeFrame); popMatrix();
    noClip();
    for(int i=0;i<hitCount;i++){
      float wx=hitTargets[i][0]-inspectorCX,wy=hitTargets[i][1]-inspectorCY;
      hitTargets[i][0]=inspectorCX+editPanX+wx*editZoom;
      hitTargets[i][1]=inspectorCY+editPanY+wy*editZoom;
      hitTargets[i][2]*=editZoom;}
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
    float ch=height-canvasY-48;
    float canvasR=min(width,ch)*0.45;
    float ext=viewExtent(twoState!=null&&twoState.length>0?twoState[0]:null);
    float vs=(ext>0)?canvasR/ext:1.0;
    float ts=vs*viewZoom;
    inspectorCX=width/2.0;
    inspectorCY=canvasY+ch/2.0;
    resetHitTargets(512);
    clip(0,(int)canvasY,width,(int)(vHudY()-4-canvasY));
    pushMatrix(); translate(inspectorCX+viewPanX,inspectorCY+viewPanY); scale(ts); drawFramework(activeFrame); popMatrix();
    noClip();
    for(int i=0;i<hitCount;i++){
      float wx=hitTargets[i][0]-inspectorCX, wy=hitTargets[i][1]-inspectorCY;
      hitTargets[i][0]=inspectorCX+viewPanX+wx*ts;
      hitTargets[i][1]=inspectorCY+viewPanY+wy*ts;
      hitTargets[i][2]*=ts;}
    drawViewHUD();
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
  if(appMode==0&&mouseX>=sbX()){sbMousePressed(mouseX,mouseY);return;}
  for(int i=0;i<numButtons;i++){
    float x=btnX(i),y=btnTop;
    if(mouseX>x&&mouseX<x+btnW&&mouseY>y&&mouseY<y+btnH){
      if(i==0&&appMode!=0){resetViewCollapsed();editZoom=1;editPanX=0;editPanY=0;}
      if(i==1&&appMode!=1){collapseAllForView();viewZoom=1;viewPanX=0;viewPanY=0;}
      appMode=i;return;}}
  if(appMode==0){
    if(editingLabel)commitLabelEdit(selectedNodeState());
    if(editingSubLabel)commitSubLabelEdit(selectedNodeState());
    if(editingFilename)commitFilenameEdit();
    selectedNode=pickNode(mouseX,mouseY);
    editIsPanning=false;
  } else {
    viewIsDragging=false;
    if(vHudButtonHit(0,mouseX,mouseY)){viewZoom=1;viewPanX=0;viewPanY=0;return;}
    if(vHudButtonHit(1,mouseX,mouseY)){collapseAllForView();return;}
    if(vHudButtonHit(2,mouseX,mouseY)){resetViewCollapsed();return;}
    if(vHudFnHit(mouseX,mouseY)){editingFilename=true;return;}
    if(vHudSaveHit(mouseX,mouseY)){commitFilenameEdit();saveCanvasImage(filenameBuffer);return;}
    viewDragStartX=mouseX; viewDragStartY=mouseY;}}

void mouseDragged(){
  if(appMode==0){
    if(mouseX>=sbX()){sbMouseDragged(mouseX,mouseY); return;}
    // Middle mouse or space+drag to pan in edit mode
    if(mouseButton==CENTER||editIsPanning){
      editIsPanning=true;
      editPanX+=mouseX-pmouseX; editPanY+=mouseY-pmouseY;}
    return;}
  viewIsDragging=true;
  viewPanX+=mouseX-pmouseX; viewPanY+=mouseY-pmouseY;}

void mouseReleased(){
  if(appMode==0){editIsPanning=false; sbMouseReleased(); return;}
  if(!viewIsDragging){
    int hit=pickNode(mouseX,mouseY);
    if(hit>=0){NodeState ns=resolveHit((int)hitTargets[hit][3]);
      if(ns!=null&&ns.isHub())ns.viewCollapsed=!ns.viewCollapsed;}}
  viewIsDragging=false;}

void mouseWheel(MouseEvent e){
  float factor=e.getCount()<0?1.1:0.9;
  if(appMode==0){
    float mx=mouseX-inspectorCX-editPanX, my=mouseY-inspectorCY-editPanY;
    editPanX-=mx*(factor-1); editPanY-=my*(factor-1);
    editZoom=constrain(editZoom*factor,0.1,10);
  } else {
    float mx=mouseX-inspectorCX-viewPanX, my=mouseY-inspectorCY-viewPanY;
    viewPanX-=mx*(factor-1); viewPanY-=my*(factor-1);
    viewZoom=constrain(viewZoom*factor,0.1,10);}}

void keyPressed(){
  if(appMode!=0){if(editingFilename)sbKeyPressed();return;}
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

float btnX(int i){ return (width-(numButtons*btnW+(numButtons-1)*btnGap))/2.0+i*(btnW+btnGap); }

void drawButtons(){
  String[]modeLabels={"Edit","View"};
  for(int i=0;i<numButtons;i++){
    float x=btnX(i),y=btnTop;boolean active=(appMode==i);
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

// ── View HUD ─────────────────────────────────────────────────────────────────
// Left group: Reset zoom, Collapse all, Expand all
// Right group: [filename field] [Save image]
final String[] VHD_LABELS = {"Reset zoom","Collapse all","Expand all"};
final float VHD_BTN_W=100, VHD_BTN_H=28, VHD_BTN_GAP=10;
final float VHD_FN_W=180, VHD_SAVE_W=100;
float vHudY(){ return height-44; }

// Left 3 buttons centred in left half; save group right-aligned
float vHudBtnX(int i){
  float leftGroupW = VHD_BTN_W*3+VHD_BTN_GAP*2;
  float leftStart  = (width/2.0-10-leftGroupW)/2.0;
  return leftStart+i*(VHD_BTN_W+VHD_BTN_GAP);}
float vHudFnX(){ return width-16-VHD_SAVE_W-8-VHD_FN_W; }
float vHudSaveX(){ return width-16-VHD_SAVE_W; }

void drawViewHUD(){
  fill(248);noStroke();rect(0,vHudY()-4,width,height-vHudY()+4);
  stroke(SB_LINE);strokeWeight(1);line(0,vHudY()-4,width,vHudY()-4);

  // Left group
  for(int i=0;i<3;i++){
    boolean hov=vHudButtonHit(i,mouseX,mouseY);
    fill(hov?color(220,235,255):color(238));stroke(hov?color(80,140,210):BORDER);strokeWeight(hov?1.8:1);
    rect(vHudBtnX(i),vHudY(),VHD_BTN_W,VHD_BTN_H,5);
    fill(hov?color(30,80,160):FG);noStroke();textSize(11);textAlign(CENTER,CENTER);
    text(VHD_LABELS[i],vHudBtnX(i)+VHD_BTN_W/2,vHudY()+VHD_BTN_H/2);}

  // Filename field (right side)
  float fy=vHudY(), fx=vHudFnX();
  boolean fe=editingFilename;
  fill(fe?color(230,240,255):color(238));stroke(fe?color(80,140,210):color(200));strokeWeight(fe?1.8:1);
  rect(fx,fy,VHD_FN_W,VHD_BTN_H,4);
  String display=filenameBuffer.length()>0?filenameBuffer:"auto timestamp";
  fill(filenameBuffer.length()==0&&!fe?MUTED:FG);noStroke();textSize(11);textAlign(LEFT,CENTER);
  text((fe?filenameBuffer:display)+(fe&&frameCount%60<30?"|":""),fx+6,fy+VHD_BTN_H/2);

  // Save image button
  boolean shov=vHudSaveHit(mouseX,mouseY);
  fill(shov?color(220,235,255):color(238));stroke(shov?color(80,140,210):BORDER);strokeWeight(shov?1.8:1);
  rect(vHudSaveX(),fy,VHD_SAVE_W,VHD_BTN_H,5);
  fill(shov?color(30,80,160):FG);noStroke();textSize(11);textAlign(CENTER,CENTER);
  text("Save image",vHudSaveX()+VHD_SAVE_W/2,fy+VHD_BTN_H/2);}

boolean vHudButtonHit(int i,float mx,float my){
  float x=vHudBtnX(i),y=vHudY();
  return mx>=x&&mx<=x+VHD_BTN_W&&my>=y&&my<=y+VHD_BTN_H;}
boolean vHudFnHit(float mx,float my){
  return mx>=vHudFnX()&&mx<=vHudFnX()+VHD_FN_W&&my>=vHudY()&&my<=vHudY()+VHD_BTN_H;}
boolean vHudSaveHit(float mx,float my){
  return mx>=vHudSaveX()&&mx<=vHudSaveX()+VHD_SAVE_W&&my>=vHudY()&&my<=vHudY()+VHD_BTN_H;}

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
