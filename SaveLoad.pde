// ── SaveLoad.pde ──────────────────────────────────────────────────────────────
// Handles save/load state (JSON) and save image (PNG).
// Images are embedded as base64 strings in the JSON.
// ─────────────────────────────────────────────────────────────────────────────

import java.util.Base64;
import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.ByteArrayInputStream;

// ── Save image ────────────────────────────────────────────────────────────────
void saveCanvasImage(String customName) {
  // Render only the diagram area — exclude button bar, sidebar, HUD
  float cx = (width - SB_W) / 2.0;
  float cy = canvasY + (height - 20 - canvasY) / 2.0;
  int cw   = width - SB_W;
  int ch   = (int)(height - canvasY - 20);

  PGraphics pg = createGraphics(cw, ch, JAVA2D);
  pg.beginDraw();
  pg.background(255);

  if (activeFrame >= 0) {
    // Temporarily redirect hit registration to a dummy — we only want drawing
    pg.pushMatrix();
    pg.translate(cx, cy - canvasY);  // shift to canvas-relative center
    // Replay framework draw into pg
    drawFrameworkToPG(pg, activeFrame);
    pg.popMatrix();
  }

  pg.endDraw();

  String filename;
  if (customName != null && customName.trim().length() > 0) {
    filename = "data/" + customName.trim() + ".png";
  } else {
    filename = "data/diagram_" + year() + nf(month(),2) + nf(day(),2)
             + "_" + nf(hour(),2) + nf(minute(),2) + nf(second(),2) + ".png";
  }
  pg.save(filename);
  showToast("Image saved: " + filename);
}

// Draws the framework into an offscreen PGraphics — mirrors drawFramework
// but uses pg's graphics context directly via Processing's g swap trick.
void drawFrameworkToPG(PGraphics pg, int id) {
  // Swap the current graphics context so all draw calls go to pg
  PGraphics prev = g;
  g = pg;
  // Reset hit targets temporarily so registration calls don't overflow
  float[][] savedHits = hitTargets;
  int savedCount      = hitCount;
  float savedCX       = inspectorCX;
  float savedCY       = inspectorCY;
  hitTargets   = new float[512][4];
  hitCount     = 0;
  inspectorCX  = (width - SB_W) / 2.0;
  inspectorCY  = 0;   // pg center is already translated

  switch(id) {
    case 0: drawNSpoke(nSpoke); break;
    case 1: drawNCross(nCross); break;
    case 2: drawTwoLevel(nInner, nOuter); break;
  }

  // Restore
  g            = prev;
  hitTargets   = savedHits;
  hitCount     = savedCount;
  inspectorCX  = savedCX;
  inspectorCY  = savedCY;
}

// ── Save state ────────────────────────────────────────────────────────────────
void saveState(String customName) {
  JSONObject root = new JSONObject();
  root.setInt("version", 1);
  root.setInt("activeFrame", activeFrame);

  JSONObject fw = new JSONObject();

  // NSpoke
  JSONObject spoke = new JSONObject();
  spoke.setFloat("orbitR", spokeOrbitR);
  spoke.setJSONArray("nodes", statesToJSON(spokeState));
  fw.setJSONObject("spoke", spoke);

  // NCross
  JSONObject cross = new JSONObject();
  cross.setFloat("orbitR", crossOrbitR);
  cross.setJSONArray("nodes", statesToJSON(crossState));
  fw.setJSONObject("cross", cross);

  // Nested
  JSONObject nested = new JSONObject();
  nested.setFloat("outerOrbitR", twoOuterOrbitR);
  nested.setJSONArray("nodes", statesToJSON(twoState));
  fw.setJSONObject("nested", nested);

  root.setJSONObject("frameworks", fw);

  String filename;
  if (customName != null && customName.trim().length() > 0) {
    filename = "data/" + customName.trim() + ".json";
  } else {
    filename = "data/state_" + year() + nf(month(),2) + nf(day(),2)
             + "_" + nf(hour(),2) + nf(minute(),2) + nf(second(),2) + ".json";
  }
  saveJSONObject(root, filename);
  println("Saved state: " + filename);
  showToast("State saved: " + filename);
}

// ── Load state ────────────────────────────────────────────────────────────────
void loadStateFromFile(File f) {
  if (f == null) return;
  try {
    JSONObject root = loadJSONObject(f.getAbsolutePath());
    activeFrame = root.getInt("activeFrame");
    JSONObject fw = root.getJSONObject("frameworks");

    JSONObject spoke = fw.getJSONObject("spoke");
    spokeOrbitR = spoke.getFloat("orbitR");
    spokeState  = statesFromJSON(spoke.getJSONArray("nodes"));

    JSONObject cross = fw.getJSONObject("cross");
    crossOrbitR = cross.getFloat("orbitR");
    crossState  = statesFromJSON(cross.getJSONArray("nodes"));

    JSONObject nested = fw.getJSONObject("nested");
    twoOuterOrbitR = nested.getFloat("outerOrbitR");
    twoState       = statesFromJSON(nested.getJSONArray("nodes"));

    selectedNode = -1;
    showToast("State loaded.");
  } catch (Exception e) {
    println("Load error: " + e.getMessage());
    showToast("Error loading state.");
  }
}

// ── Import node (upload node) ─────────────────────────────────────────────────
// Picks a saved state file and completely replaces the selected node with the
// imported node's full structure (all satellites and their satellites recursively).
// Only the target's position (ang) is preserved.
void importNodeFromFile(File f) {
  if (f == null) return;
  NodeState target = selectedNodeState();
  if (target == null) return;
  try {
    JSONObject root = loadJSONObject(f.getAbsolutePath());
    JSONObject fw   = root.getJSONObject("frameworks");

    NodeState imported = null;

    // Try nested first: twoState[0] IS the hub node, with satellites stored
    // recursively in its children — nodeFromJSON reconstructs the full tree.
    JSONObject nested     = fw.getJSONObject("nested");
    JSONArray  nestedNodes = nested.getJSONArray("nodes");
    if (nestedNodes.size() >= 1) {
      JSONObject centerJSON = nestedNodes.getJSONObject(0);
      if (!centerJSON.isNull("children")) {
        imported = nodeFromJSON(centerJSON);
      }
    }

    // Fall back to cross (flat array: nodes[0]=center, nodes[1..n]=satellites)
    if (imported == null) {
      JSONObject cross = fw.getJSONObject("cross");
      JSONArray  crossNodes = cross.getJSONArray("nodes");
      if (crossNodes.size() > 1) {
        imported = buildImportedHub(crossNodes, cross.getFloat("orbitR"), SLOT_CROSS);
      }
    }

    // Fall back to spoke
    if (imported == null) {
      JSONObject spoke = fw.getJSONObject("spoke");
      JSONArray  spokeNodes = spoke.getJSONArray("nodes");
      if (spokeNodes.size() > 1) {
        imported = buildImportedHub(spokeNodes, spoke.getFloat("orbitR"), SLOT_SPOKE);
      }
    }

    if (imported == null) { showToast("Nothing to import."); return; }

    // Completely replace target with the imported node — preserve only position.
    float savedAng     = target.ang;
    target.label       = imported.label;
    target.r           = imported.r;
    target.fillCol     = imported.fillCol;
    target.alpha       = imported.alpha;
    target.shapeType   = imported.shapeType;
    target.orbitCol    = imported.orbitCol;
    target.orbitDashed = imported.orbitDashed;
    target.cropToShape = imported.cropToShape;
    target.img         = imported.img;
    target.invalidateCache();
    target.subType     = imported.subType;
    target.subOrbitR   = imported.subOrbitR;
    target.subScale    = imported.subScale;
    target.children    = imported.children;
    target.ang         = savedAng;

    showToast("Node imported.");
  } catch (Exception e) {
    println("Import error: " + e.getMessage());
    showToast("Error importing node.");
  }
}

// Build a hub NodeState from a flat framework node array (cross/spoke).
// Returns the center node with hub structure applied — satellites become children.
NodeState buildImportedHub(JSONArray nodes, float orbitR, int subType) {
  if (nodes.size() < 2) return null;
  int nSats  = nodes.size() - 1;
  NodeState center = nodeFromJSON(nodes.getJSONObject(0));
  center.subType   = subType;
  center.subOrbitR = orbitR;
  center.subScale  = 1.75 * center.r / orbitR;
  NodeState[] children = new NodeState[nSats + 1];
  // children[0] is the center proxy (mirrors promote())
  children[0] = new NodeState(center.label, center.r * 0.6, 0);
  children[0].fillCol   = center.fillCol;
  children[0].shapeType = center.shapeType;
  for (int i = 0; i < nSats; i++) {
    children[i+1] = nodeFromJSON(nodes.getJSONObject(i+1));
  }
  center.children = children;
  return center;
}

// ── JSON serialisation ────────────────────────────────────────────────────────

JSONArray statesToJSON(NodeState[] states) {
  JSONArray arr = new JSONArray();
  if (states == null) return arr;
  for (int i = 0; i < states.length; i++)
    arr.setJSONObject(i, nodeToJSON(states[i]));
  return arr;
}

NodeState[] statesFromJSON(JSONArray arr) {
  if (arr == null) return new NodeState[0];
  NodeState[] states = new NodeState[arr.size()];
  for (int i = 0; i < arr.size(); i++)
    states[i] = nodeFromJSON(arr.getJSONObject(i));
  return states;
}

JSONObject nodeToJSON(NodeState ns) {
  JSONObject o = new JSONObject();
  o.setString("label",    ns.label);
  o.setFloat ("r",        ns.r);
  o.setFloat ("ang",      ns.ang);
  o.setString("fillCol",  colorToHex(ns.fillCol));
  o.setInt   ("alpha",    ns.alpha);
  o.setInt   ("shapeType",    ns.shapeType);
  o.setFloat ("labelAng",  ns.labelAng);
  o.setInt   ("labelSize", ns.labelSize);
  o.setString("orbitCol", colorToHex(ns.orbitCol));
  o.setBoolean("orbitDashed", ns.orbitDashed);
  o.setBoolean("cropToShape", ns.cropToShape);
  o.setInt   ("subType",  ns.subType);
  o.setFloat ("subOrbitR",   ns.subOrbitR);
  o.setFloat ("subScale",    ns.subScale);
  o.setFloat ("subAngOffset",ns.subAngOffset);

  // Image as base64
  if (ns.img != null) {
    o.setString("img", pimageToBase64(ns.img));
  }

  // Children recursive
  if (ns.children != null) {
    JSONArray kids = new JSONArray();
    for (int i = 0; i < ns.children.length; i++)
      kids.setJSONObject(i, nodeToJSON(ns.children[i]));
    o.setJSONArray("children", kids);
  }
  return o;
}

NodeState nodeFromJSON(JSONObject o) {
  NodeState ns = new NodeState(
    o.getString("label", "node"),
    o.getFloat ("r",     40),
    o.getFloat ("ang",   0)
  );
  ns.fillCol    = hexToColor(o.getString("fillCol",  "#F5F5F5"));
  ns.alpha      = o.getInt    ("alpha",     255);
  ns.shapeType     = o.getInt("shapeType",     0);
  ns.labelAng      = o.getFloat("labelAng",  0);
  ns.labelSize     = o.getInt  ("labelSize", 12);
  ns.orbitCol   = hexToColor(o.getString("orbitCol", "#B4B4B4"));
  ns.orbitDashed  = o.getBoolean("orbitDashed", true);
  ns.cropToShape  = o.getBoolean("cropToShape", true);
  ns.subType    = o.getInt    ("subType",   SLOT_PLAIN);
  ns.subOrbitR     = o.getFloat("subOrbitR",    80);
  ns.subScale      = o.getFloat("subScale",     1);
  ns.subAngOffset  = o.getFloat("subAngOffset", 0);

  // Image from base64
  String imgB64 = o.isNull("img") ? null : o.getString("img", null);
  if (imgB64 != null && imgB64.length() > 0) {
    ns.img = base64ToPImage(imgB64);
  }

  // Children recursive
  if (!o.isNull("children")) {
    JSONArray kids = o.getJSONArray("children");
    ns.children = new NodeState[kids.size()];
    for (int i = 0; i < kids.size(); i++)
      ns.children[i] = nodeFromJSON(kids.getJSONObject(i));
  }
  return ns;
}

// ── Color helpers ─────────────────────────────────────────────────────────────
String colorToHex(color c) {
  return String.format("#%02X%02X%02X", (int)red(c), (int)green(c), (int)blue(c));
}

color hexToColor(String hex) {
  hex = hex.replace("#","");
  int r = unhex(hex.substring(0,2));
  int g = unhex(hex.substring(2,4));
  int b = unhex(hex.substring(4,6));
  return color(r, g, b);
}

// ── Image base64 helpers ──────────────────────────────────────────────────────
String pimageToBase64(PImage img) {
  try {
    img.loadPixels();
    BufferedImage bi = new BufferedImage(img.width, img.height, BufferedImage.TYPE_INT_ARGB);
    for (int y = 0; y < img.height; y++)
      for (int x = 0; x < img.width; x++)
        bi.setRGB(x, y, img.pixels[y*img.width+x]);
    ByteArrayOutputStream baos = new ByteArrayOutputStream();
    ImageIO.write(bi, "png", baos);
    return Base64.getEncoder().encodeToString(baos.toByteArray());
  } catch (Exception e) { println("Image encode error: "+e); return ""; }
}

PImage base64ToPImage(String b64) {
  try {
    byte[] bytes = Base64.getDecoder().decode(b64);
    BufferedImage bi = ImageIO.read(new ByteArrayInputStream(bytes));
    PImage out = createImage(bi.getWidth(), bi.getHeight(), ARGB);
    out.loadPixels();
    for (int y = 0; y < bi.getHeight(); y++)
      for (int x = 0; x < bi.getWidth(); x++)
        out.pixels[y*bi.getWidth()+x] = bi.getRGB(x,y);
    out.updatePixels();
    return out;
  } catch (Exception e) { println("Image decode error: "+e); return null; }
}

// ── Toast notification ────────────────────────────────────────────────────────
String toastMsg   = "";
int    toastTimer = 0;
final int TOAST_FRAMES = 120;

void showToast(String msg) { toastMsg=msg; toastTimer=TOAST_FRAMES; }

void drawToast() {
  if (toastTimer <= 0) return;
  toastTimer--;
  float alpha = min(255, toastTimer * 6);
  fill(30, 30, 30, alpha); noStroke();
  float tw = textWidth(toastMsg) + 24;
  float tx = (width-SB_W)/2.0 - tw/2;
  float ty = height - 60;
  rect(tx, ty, tw, 30, 8);
  fill(255, alpha); textSize(12); textAlign(CENTER, CENTER);
  text(toastMsg, (width-SB_W)/2.0, ty+15);
}
