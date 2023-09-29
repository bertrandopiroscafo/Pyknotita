//@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
//@ Pyknótita V1.0 2023 by @bertrandopiroscafo   @
//@ V1.0.0 18/09/2023                            @
//@ Code pushed to Github -> 28/09/2023          @
//"@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

import blobDetection.*;
import controlP5.*;
import themidibus.*;
import processing.video.*;
import milchreis.imageprocessing.*;
import java.awt.Rectangle;
import java.awt.Point;
import processing.awt.PSurfaceAWT;
import javax.swing.JFrame;


// global variables
BlobDetection _theBlobDetection;
int _blobMaxNb = 1000;
int _blobLinesMaxNb = 4000;
int _blobTrianglesMaxNb = 500;

// CAM and resolution
Capture _cam;
boolean _streaming = true;
int CAM_WIDTH  = 640;
int CAM_HEIGHT = 480; 

PImage _img;
int WIDTH  = 640;
int HEIGHT = 480; 
float _gain = 1;
int _area = 0;

float _previousArea = 0.0;
float _bboxMaxWidth = WIDTH;
float _bboxMaxHeight = HEIGHT;
float _bboxMaxArea = WIDTH * HEIGHT;
float _bboxMinArea = 0;
int _counter = 0;
float _thresholdValue = 0.592;
float _triggerValue = 0.5;

ControlP5 _controlP5;
Slider _thresholdSlider;
Slider _CC_Slider;
Slider _triggerSlider;
Toggle _triggerToggle;
Textarea _textArea;
Println _console;

MidiBus _myBus; // The MidiBus
int CC_Value = 0;
int CC_Value_old = 0;
int CC_CHANNEL = 0;
int CC_NUMBER_SEND = 71; 
int CC_NUMBER_RECEIVE = 0;
int NOTE_NUMBER = 48;
boolean _newFrame=false;
boolean _drawEdges = true;
boolean _drawBBOX = true;
boolean _alwaysOnTop = true;

float _EMA_a = 0.5;

Rectangle _userArea;
int _mode = 0;
boolean _sendCC = true;
boolean _sendNOTE = false;
boolean _fx = false;

PImage _imgDKBP;

JFrame frame;

JFrame getJFrame() {
  PSurfaceAWT surf = (PSurfaceAWT) getSurface();
  PSurfaceAWT.SmoothCanvas canvas = (PSurfaceAWT.SmoothCanvas) surf.getNative();
  return (JFrame) canvas.getFrame();
}

// ==================================================
// setup()
// ==================================================
void setup()
{
  // Size of applet
  size(1240, 490);
  
  // background color
  background(color(128, 128, 128));
  
  // BP icon
  _imgDKBP = loadImage("dkbp.png");
  
  // Sinon, quand on appuie sur le bouton close,
  // car ça plante en quittant quand on envoie les messages MIDI
  frame = getJFrame();
  frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
 
  surface.setTitle("Pyknótita V1.1 2023");
  surface.setAlwaysOnTop(true);
  
  _controlP5 = new ControlP5(this);
  _thresholdSlider = _controlP5.addSlider("threshold")
 .setRange(0,100)
 .setValue(17/*63.40*/)
 .setPosition(650,10)
 .setSize(500,10);

  _controlP5.addSlider("gain")
 .setRange(1,5)
 .setValue(1.2)
 .setPosition(650,25)
 .setSize(500,10);
 
  _controlP5.addToggle("draw edges")
 .setValue(true)
 .setPosition(650,50)
 .setSize(10,10); 
 
  _controlP5.addToggle("draw bbox")
 .setValue(true)
 .setPosition(640 + 80,50)
 .setSize(10,10); 
 
 _controlP5.addToggle("streaming")
 .setValue(true)
 .setPosition(640 + 150,50)
 .setSize(10,10); 
 
 _controlP5.addToggle("always on top")
 .setValue(true)
 .setPosition(640 + 220,50)
 .setSize(10,10); 
 
 _controlP5.addToggle("fx")
 .setValue(false)
 .setPosition(640 + 290,50)
 .setSize(10,10); 
 
 _controlP5.addButton("shooting")
 .setPosition(640 + 320,50)
 .setSize(50,20); 
 
  _controlP5.addSlider("bbox max width")
 .setRange(1,WIDTH)
 .setValue(WIDTH)
 .setPosition(650,90)
 .setSize(500,10);
 
  _controlP5.addSlider("bbox max height")
 .setRange(1,HEIGHT)
 .setValue(HEIGHT)
 .setPosition(650,105)
 .setSize(500,10);
 
 _controlP5.addSlider("bbox min area")
 .setRange(1,WIDTH * HEIGHT / 20)
 .setValue(1)
 .setPosition(650,120)
 .setSize(500,10);
 
  _controlP5.addSlider("bbox max area")
 .setRange(1,WIDTH * HEIGHT)
 .setValue(WIDTH * HEIGHT)
 .setPosition(650,135)
 .setSize(500,10);
 
  _controlP5.addSlider("alpha ema")
 .setRange(0, 1)
 .setValue(0.5)
 .setPosition(650,150)
 .setSize(500,10);
 
 _CC_Slider = _controlP5.addSlider("MIDI CC OUT")
 .setRange(0, 127)
 .setValue(0)
 .setPosition(650,165)
 .setSize(500,20)
 .setColorForeground(color(255, 0, 0))
 .lock();
 
 _triggerSlider = _controlP5.addSlider("gate")
 .setRange(0, 127)
 .setValue(127)
 .setPosition(650,195)
 .setSize(500,10);
 
 _triggerToggle = _controlP5.addToggle("triggerToggle")
 .setValue(false)
 .setPosition(640 + 570,195)
 .setSize(20,20); 
 //_triggerToggle.setMode(ControlP5.SWITCH);
 _triggerToggle.getCaptionLabel().setVisible(false);
 
 _textArea = _controlP5.addTextarea("txt")
                  .setPosition(650, 420)
                  .setSize(500, 60)
                  .setFont(createFont("helvetica", 12))
                  .setLineHeight(14)
                  .setColor(color(51, 255, 0))
                  .setColorBackground(color(0, 100))
                  .setColorForeground(color(255, 100));
                  
  _console = _controlP5.addConsole(_textArea);
  _console.play();
 
  // Capture 
  String[] cameras = Capture.list();  
  
  
  if (cameras.length == 0) {
    println("There are no cameras available for capture.");
    exit();
  } 
  else {
    println("Available cameras:");
    for (int i = 0; i < cameras.length; i++) {
      println(cameras[i]);
    }
  }
  
  
  // Capture initialization
  if (cameras.length == 1) {
    // webcam interne du mac
    _cam = new Capture(this, CAM_WIDTH, CAM_HEIGHT, cameras[0], 25/* FPS*/); // works with Catalina and Big Sur
  }
  else {
    // webcam externe
    _cam = new Capture(this, CAM_WIDTH, CAM_HEIGHT, cameras[1], 25); // works with FPS = 25 with Catalina !!!
  }
  _cam.start();
  
  _img = new PImage(CAM_WIDTH - 2, CAM_HEIGHT - 2); 
  
  initializeBlobDetection();
  
  // MIDI
  MidiBus.list(); 
  //_myBus = new MidiBus(this, -1, "USB MIDI Interface"); // External
  _myBus = new MidiBus(this, -1, "BGC DRUM KIT");
 
  // Bio
  printIntro();

}

void printIntro()
{
  //println(" "); plante l'appli !!!
  println("---------------------------------------------------------------------------------");
  println("Pyknótita is written by Bertrand GILLES-CHATELETS. Please see my Instagram account @bertrandopiroscafo for more information about my work. All is running fine! Have fun :)");
  //println("All is running fine! Have fun :)");
  //println("Have fun! :)");
}

void printDKBPinfo()
{
  println("[info] Die Kleinen Blauen Pferde - Franz Marc (1911) - Staatsgalerie Stuttgart ");
  
}

void initializeBlobDetection()
{
  _theBlobDetection = new BlobDetection(_img.width, _img.height);
  _theBlobDetection.setPosDiscrimination(false);
  _theBlobDetection.setThreshold(_thresholdValue);
  _theBlobDetection.computeBlobs(_img.pixels);
  
  _userArea = new Rectangle(0, 0, WIDTH - 2, HEIGHT - 2);
}


// ==================================================
// draw()
// ==================================================
void draw()
{  
  
  if (/*_newFrame == true*/_cam.available())
  {
    //_newFrame=false;
    _cam.read();
    _img.copy(_cam, 0, 0, _cam.width, _cam.height, 
        0, 0, _img.width, _img.height);
        
    if (_fx == true)
    {
       _img = RetroConsole.applyGameboy(_img, 4);
    }
    
    image(_img, 0, 0, _cam.width, _cam.height);
    image(_imgDKBP, 660, 220, 380, 190);
    
    fastblur(_img, 2);   
    _theBlobDetection.setThreshold(_thresholdValue / 100.0f);
    _theBlobDetection.computeBlobs(_img.pixels);
    drawBlobsAndEdges(_drawBBOX,_drawEdges);
    drawUserArea();
    computeAndSendCC_Value(_area);
  }
}
/*
void captureEvent(Capture cam)
{
  //cam.read();
  //_newFrame = true;
}
*/

// ===================================================
// MMI
// ===================================================
void controlEvent(ControlEvent theEvent) 
{
 if (theEvent.isController()) 
 { 
  if (theEvent.getController().getName()=="threshold") 
  {
    _thresholdValue = theEvent.getController().getValue();
  }
  if (theEvent.getController().getName()=="gain") 
  {
     _gain = theEvent.getController().getValue();
  }
  if (theEvent.getController().getName()=="draw edges") 
  {
    if (theEvent.getController().getValue() == 1.0)
    {
      _drawEdges = true;
      println("[info] Draw edges is enabled");
    }
    else
    { 
      _drawEdges = false;
      println("[info] Draw edges is disabled");
    }
  }
  if (theEvent.getController().getName()=="draw bbox") 
  {
    if (theEvent.getController().getValue() == 1.0)
    {
      _drawBBOX = true;
      println("[info] Draw bounding box is enabled");
    }
    else
    {
      _drawBBOX = false;
      println("[info] Draw bounding box is disabled");
    }
  }
  if (theEvent.getController().getName()=="streaming") 
  {
    if (theEvent.getController().getValue() == 1.0)
    {
      _streaming = true;
      if (_cam != null)
      {
        _cam.start();
        println("[info] Streaming is enabled");
      }
    }
    else
    {
      _streaming = false;
      if (_cam != null) 
      {
        _cam.stop();
        println("[info] Streaming is disabled");
      }
    }
  }
  if (theEvent.getController().getName()=="always on top") 
  {
    if (theEvent.getController().getValue() == 1.0)
    {
      _alwaysOnTop = true;
      surface.setAlwaysOnTop(true);
      println("[info] App is always on top");
    }
    else
    { 
      _alwaysOnTop = false;
      surface.setAlwaysOnTop(false);
      println("[info] App is not always on top");
    }
  }
  if (theEvent.getController().getName()=="fx") 
  {
    if (theEvent.getController().getValue() == 1.0)
    {
      _fx = true;
      println("[info] FX is enabled");
    }
    else
    {
      _fx = false;
      println("[info] FX is disabled");
    }
  }
  if (theEvent.getController().getName()=="shooting") 
  {
    String s = String.valueOf(year())
    +"_"
    +String.valueOf(month())
    +"_"
    +String.valueOf(day())
    +"_"
    +String.valueOf(hour())
    +"_"
    +String.valueOf(minute())
    +"_"
    +String.valueOf(second())  
    +".tif";
    saveFrame("shooting/" + s);
    println("[info] shooting " + s + " done");
  }
  
  if (theEvent.getController().getName()=="bbox max width") 
  {
    _bboxMaxWidth = theEvent.getController().getValue();
  }
  if (theEvent.getController().getName()=="bbox max height") 
  {
    _bboxMaxHeight = theEvent.getController().getValue();
  }
  if (theEvent.getController().getName()=="bbox min area") 
  {
    _bboxMinArea = theEvent.getController().getValue();
  }
  if (theEvent.getController().getName()=="bbox max area") 
  {
    _bboxMaxArea = theEvent.getController().getValue();
  }
  if (theEvent.getController().getName()=="alpha ema") 
  {
    _EMA_a = theEvent.getController().getValue();
  }
  if (theEvent.getController().getName()=="gate") 
  {
    _triggerValue = theEvent.getController().getValue();
  }
 }
}

// ==================================================
// MIDI
// ==================================================
void computeAndSendCC_Value(int area)
{
  if (_sendCC == false) return;
  
  _previousArea = EMA(area, _previousArea);
  CC_Value = (int) ((float)_previousArea / (float)(_userArea.width * _userArea.height) * 127 * _gain);
  
  //println("previous area = ", _previousArea);
  //println("user area = ", _userArea.width * _userArea.height);
  //println("gain = ", _gain);
  
  if (CC_Value > 127)
  {
    //println("Warning! CC saturated");
    CC_Value = 127;
  } 
  
  if (CC_Value != CC_Value_old) 
  {
    CC_Value_old = CC_Value;
    //print("[", ++_counter);
    //println("] CC Value = ", CC_Value);
    _CC_Slider.setValue(CC_Value);
    if (_myBus != null) {
      _myBus.sendControllerChange(CC_CHANNEL, CC_NUMBER_SEND, CC_Value);
    }
    if (CC_Value >= _triggerValue && _sendNOTE == false)
    {
      // NOTE ON
      println("[info] Gate is ON");
      _triggerToggle.setValue(true);
      if (_myBus != null) {
        _myBus.sendNoteOn(CC_CHANNEL, NOTE_NUMBER, CC_Value);
      }
      //_sample.play();
      _sendNOTE = true;
    }
    else
    {
      // NOTE OFF
      if (CC_Value < _triggerValue && _sendNOTE == true)
      {
        println("[info] Gate is OFF");
        _triggerToggle.setValue(false);
        if (_myBus != null) {
          _myBus.sendNoteOff(CC_CHANNEL, NOTE_NUMBER, CC_Value);
        }
        _sendNOTE = false;
      }
    }
  }
}

void controllerChange(int channel, int number, int value) {

  // Receive a controllerChange
  
  //println();
  //println("Controller Change:");
  //println("--------");
  //println("Channel:"+channel);
  //println("Number:"+number);
  //println("Value:"+value);
  if (number == CC_NUMBER_RECEIVE)
  {
    if (value >= 0 && value <= 127)
    {
      //println("setting threshold by MIDI CC");
      _thresholdValue = value / 127.0 * 100.0;
      _thresholdSlider.setValue(_thresholdValue);
    }
  }
}

// ==================================================
// drawBlobsAndEdges()
// ==================================================
void drawBlobsAndEdges(boolean drawBlobs, boolean drawEdges)
{
  noFill();
  Blob b;
  EdgeVertex eA, eB;
  _area = 0;
  int theAreaUser = 0;
  
  //println("nb of BLOBs detected = ", _theBlobDetection.getBlobNb());
  
  for (int n=0 ; n<_theBlobDetection.getBlobNb() ; n++)
  {
    b=_theBlobDetection.getBlob(n);
    if (b!=null)
    {
      if (check(b) == true)
      {
        _area += b.w*_img.width * b.h*_img.height;
      }
      // Edges
      if (drawEdges)
      {
        strokeWeight(1);
        //stroke(0, 255, 0);
        stroke(0, 191, 255);
        //stroke(255,0,0);
        if (check(b) == true)
        {
            for (int m=0;m<b.getEdgeNb();m++)
            {
              eA = b.getEdgeVertexA(m);
              eB = b.getEdgeVertexB(m);
              if (eA !=null && eB !=null)
              {
              line(
                    eA.x*_img.width, eA.y*_img.height, 
                    eB.x*_img.width, eB.y*_img.height
                    );
              }
            }
        }   
      }
      // Blobs
      if (drawBlobs)
      {
        strokeWeight(1);
        stroke(255, 0, 0);   
        if (check(b) == true)
        {
          fill(255,0,0,50);
          rect(b.xMin*_img.width, b.yMin*_img.height, 
             b.w*_img.width, b.h*_img.height);
        }
   
      }
    }
  }
  
  theAreaUser = _userArea.width * _userArea.height;
  
  // en sommant les surfaces, on ne tient pas compte des recouvrements
  //  A améliorer.
  if (_area > theAreaUser)
  {
     _area = theAreaUser; 
     println("[warning] Cumuled area troncated to user area");
  }
  
}

boolean check(Blob b)
{
  boolean res = false;
  
  float area = b.w * _img.width * b.h *_img.height ;
  Rectangle blobBBox = new Rectangle((int)(b.xMin*_img.width), (int)(b.yMin*_img.height), 
                                     (int)(b.w*_img.width), (int)(b.h*_img.height));
  
  if ((b.w * _img.width > _bboxMaxWidth) || (b.h *_img.height > _bboxMaxHeight) ||
       (area > _bboxMaxArea) || (area < _bboxMinArea) || /*!blobBBox.intersects(_userArea))*/!_userArea.contains(blobBBox)) 
  {
    res = false;
  }
  else 
  {
    res = true; 
  }
  return res;
}

// ==================================================
// Exponential Moving Average (EMA) Filter
// ==================================================
float EMA(float v, float previousOutput) {
  return _EMA_a * v  + (1 - _EMA_a) * previousOutput; 
}

// ==================================================
// Mouse control
// ===================================================
void mousePressed() 
{
  if (mouseX <= WIDTH && mouseY <= HEIGHT) 
  {
    _mode = 1;
    _sendCC = false;
    _userArea.x = mouseX;
    _userArea.y = mouseY;
    _userArea.width = 0;
    _userArea.height = 0;  
  }
  else
  {
     _mode = 0; 
     if (new Rectangle(660, 220, 380, 190).contains(new Point(mouseX, mouseY)) == true)
     {
       printDKBPinfo();
     }
  }
}

void mouseDragged() 
{
  if (_mode == 1)
  {
    _userArea.width = abs(_userArea.x - mouseX);
    _userArea.height = abs(_userArea.y - mouseY);
  }
}

void mouseReleased() {
  // bug fixed 20230925
  if (_mode == 1) 
  {
    _mode = 2;
    _sendCC = true;
    println("[info] User area resized: density is computed inside the blue rectangle");
    if (_userArea.width < 2 && _userArea.height < 2) 
    {
      println("[warning] User area is very small: no detection may be occur");
    }
  }
  
}

void drawUserArea()
{
   strokeWeight(2);
   noFill();
   stroke(0, 128, 255);
   if ((_userArea.x + _userArea.width) < WIDTH &&
       (_userArea.y + _userArea.height) < HEIGHT) 
   {
     rect(_userArea.x, _userArea.y, _userArea.width, _userArea.height);
   }
   else 
   {
     // si on sort du cadre, on repart sur la surface utilisateur initiale
     // qui est maximale
     _userArea.setLocation(0, 0);
     _userArea.setSize(WIDTH - 2, HEIGHT - 2);
   }
}

void keyPressed() {
  if (key == 72) {
    // H -> hide control panel
    surface.setSize(640, 480);
  } else if (key == 83) {
    // S -> show control panel
    surface.setSize(1240, 490);
  }
}

// ==================================================
// Super Fast Blur v1.1
// by Mario Klingemann 
// <http://incubator.quasimondo.com>
// ==================================================
void fastblur(PImage img,int radius)
{
 if (radius<1){
    return;
  }
  int w=img.width;
  int h=img.height;
  int wm=w-1;
  int hm=h-1;
  int wh=w*h;
  int div=radius+radius+1;
  int r[]=new int[wh];
  int g[]=new int[wh];
  int b[]=new int[wh];
  int rsum,gsum,bsum,x,y,i,p,p1,p2,yp,yi,yw;
  int vmin[] = new int[max(w,h)];
  int vmax[] = new int[max(w,h)];
  int[] pix=img.pixels;
  int dv[]=new int[256*div];
  for (i=0;i<256*div;i++){
    dv[i]=(i/div);
  }

  yw=yi=0;

  for (y=0;y<h;y++){
    rsum=gsum=bsum=0;
    for(i=-radius;i<=radius;i++){
      p=pix[yi+min(wm,max(i,0))];
      rsum+=(p & 0xff0000)>>16;
      gsum+=(p & 0x00ff00)>>8;
      bsum+= p & 0x0000ff;
    }
    for (x=0;x<w;x++){

      r[yi]=dv[rsum];
      g[yi]=dv[gsum];
      b[yi]=dv[bsum];

      if(y==0){
        vmin[x]=min(x+radius+1,wm);
        vmax[x]=max(x-radius,0);
      }
      p1=pix[yw+vmin[x]];
      p2=pix[yw+vmax[x]];

      rsum+=((p1 & 0xff0000)-(p2 & 0xff0000))>>16;
      gsum+=((p1 & 0x00ff00)-(p2 & 0x00ff00))>>8;
      bsum+= (p1 & 0x0000ff)-(p2 & 0x0000ff);
      yi++;
    }
    yw+=w;
  }

  for (x=0;x<w;x++){
    rsum=gsum=bsum=0;
    yp=-radius*w;
    for(i=-radius;i<=radius;i++){
      yi=max(0,yp)+x;
      rsum+=r[yi];
      gsum+=g[yi];
      bsum+=b[yi];
      yp+=w;
    }
    yi=x;
    for (y=0;y<h;y++){
      pix[yi]=0xff000000 | (dv[rsum]<<16) | (dv[gsum]<<8) | dv[bsum];
      if(x==0){
        vmin[y]=min(y+radius+1,hm)*w;
        vmax[y]=max(y-radius,0)*w;
      }
      p1=x+vmin[y];
      p2=x+vmax[y];

      rsum+=r[p1]-r[p2];
      gsum+=g[p1]-g[p2];
      bsum+=b[p1]-b[p2];

      yi+=w;
    }
  }

}
