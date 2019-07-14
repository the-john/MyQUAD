import processing.serial.*;
import processing.opengl.*;



/* ================================ Keyboard Variables ================================ */
int control_int = 0;
int result;
/* ==================================================================================== */



/* ============================== Serial RX/TX Variables ============================== */
int lf = 10;    // Linefeed in ASCII
String rxString = null;
String txString = null;
String curCommand = null;
String lastCommand = null;
Serial myPort;  // The serial port
int fifoFlag = 0;
/* ==================================================================================== */



/* =============================== Mouse Input Variables ============================== */
int joy_y = 0; // Joystick Y zero
int joy_x = 0; // Joystick X zero
int joy_x_out = 0; // int used to output actual x val (scaled to +/- 180)
int joy_y_out = 0; // int used to output actual y val (scaled to +/- 180)
boolean joystick_active = false;
/* ==================================================================================== */



/* =============================== Throttle Variables ================================= */
int thr = 0;
int thr_out = 0;
int thrChange = 0;
int yaw = 0; // '1' = center, '0' = left, '2' = right
int yaw_out = 1;
int zero_val = 0; // this is your zero val.
int total_out;
int b = 0;
/* ==================================================================================== */



/* ================================ Display Variables ================================= */
int quadSize;
int quadXPos, quadYPos;

int gaugeSize;
int yawGaugeXPos, yawGaugeYPos;
int pitchGaugeXPos, pitchGaugeYPos;
int rollGaugeXPos, rollGaugeYPos;

int joyboxSize;
int joyboxXPos, joyboxYPos;

int throttleWidth, throttleHeight;
int throttleXPos, throttleYPos;

int yawWidth, yawHeight;
int yawXPos, yawYPos;

PFont font128, font32, font24, font16, font16b, fixed;
/* ==================================================================================== */



/* =============================== Quad Info Variables ================================ */
float quadYaw, quadPitch, quadRoll;
/* ==================================================================================== */



// ================================
// INITIAL SETUP
// ================================
void setup() 
{
  // initialize viewport to use OpenGL renderer (P3D also okay)
  size(800, 600, OPENGL);
  frameRate(30);
  
  // position and sizes of various elements
  // ======================================
  
  // 3D quad representation, centered horizontally and slightly below vertical center
  quadSize = 300;
  quadXPos = width/2;
  quadYPos = height/2 + 50;

  // yaw/pitch/roll gauges, centered above 3D quad
  gaugeSize = 80;  
  yawGaugeXPos = quadXPos - 120;
  yawGaugeYPos = quadYPos - 170;
  pitchGaugeXPos = quadXPos;
  pitchGaugeYPos = quadYPos - 170;
  rollGaugeXPos = quadXPos + 120;
  rollGaugeYPos = quadYPos - 170;
  
  // joystick control area, 25px away from bottom/right corner
  joyboxSize = 180;
  joyboxXPos = width - (joyboxSize/2) - 25;
  joyboxYPos = quadYPos - 120;
  
  // throttle control area, 25px away from left side, vertically centered
  // (this control bar is always oriented VERTICALLY)
  throttleWidth = 70;
  throttleHeight = 400;
  throttleXPos = quadXPos - 275;
  throttleYPos = height/2;
  
  // yaw control area, 25px away from bottom side, horizontally centered
  // (this control bar is always oriented HORIZONTALLY)
  yawWidth = 400;
  yawHeight = 70;
  yawXPos = width/2;
  yawYPos = quadYPos + 120;
  
  // setup nice lighting and antialiasing
  lights();
  smooth();
  
  // load font data
  font128 = loadFont("Calibri-128.vlw");
  font32 = loadFont("Calibri-32.vlw");
  font24 = loadFont("Calibri-24.vlw");
  font16 = loadFont("Calibri-16.vlw");
  font16b = loadFont("Calibri-Bold-16.vlw");
  fixed = loadFont("Consolas-Bold-16.vlw");

  // list all the available serial ports for debugging
  //println(Serial.list());

  // open and initialize serial port
  //myPort = new Serial(this, Serial.list()[1], 57600);
  myPort = new Serial(this, "COM10", 57600);
  myPort.bufferUntil(lf); // buffer until line feed
}



// ================================
// MAIN DRAW/PROCESS LOOP
// ================================
void draw() 
{
  background(0); // black
  noStroke();
  
  // scale current joystick position to 0-360
  // (controlled by mouse drag or arrow keys)
  joy_x_out = joy_x * 360/joyboxSize + 180;
  joy_y_out = joy_y * 360/joyboxSize + 180;
  
  // apply any active throttle adjustments
  // controlled by 'W' and 'S' keys
  if (thrChange < 0 && thr > 0) thr = max(0, thr + thrChange);
  else if (thrChange > 0 && thr < 99) thr = min(99, thr + thrChange);
  thr_out = int(thr);
  
  drawTitle();
  draw3DQuad();
  drawYawGauge();
  drawPitchGauge();
  drawRollGauge();
  drawJoybox();
  drawThrottle();
  drawYaw();
  
  if (fifoFlag > 0) {
      fifoFlag--;
      if (fifoFlag % 20 > 10) {
          // this makes it blink until it disappears
          drawFIFOOverflowIndicator();
      }
  }
  
  // send command if we have changed something since last command    
  curCommand = transmit_assit(joy_x_out, joy_y_out, thr_out, yaw_out);
  if (!curCommand.equals(lastCommand)) {
      myPort.write(curCommand); // send control data to arduino
      println(curCommand); // not to fix this to send out thr info later
  }
  lastCommand = curCommand;
}



// ================================
// FIFO OVERFLOW INDICATOR DISPLAY
// ================================
void drawFIFOOverflowIndicator() {
  rectMode(CENTER);
  fill(255, 0, 0); // red backdrop
  rect(width/2, 85, 130, 20);
  textAlign(CENTER);
  textFont(font16b);
  fill(255); // white text
  text("FIFO OVERFLOW", width/2, 90);
}



// ================================
// TITLE DISPLAY
// ================================
void drawTitle() {
  rectMode(CENTER);
  fill(30); // dark backdrop for title
  rect(width/2 + 5, 45, 600, 50);
  fill(180); // gray box for title
  rect(width/2, 40, 600, 50);

  textAlign(CENTER);
  textFont(font32);
  fill(255); // white embossed 1px title text layer
  text("Intel Ultimate Engineering Experience", width/2, 51);
  fill(0); // black main title text
  text("Intel Ultimate Engineering Experience", width/2, 50);
}



// ================================
// QUAD DISPLAY
// ================================
void draw3DQuad() {
  // draw 3D representation of quad
  pushMatrix();
  translate(quadXPos, quadYPos);
  rotateY(-radians(quadYaw)); // yaw
  rotateX(-radians(quadPitch)); // pitch
  rotateZ(-radians(quadRoll)); // roll
  scale(float(quadSize) / 200.0);

  // draw main body in red
  fill(255, 0, 0, 200);
  box(10, 10, 200);
  
  // draw front-facing tip in blue
  fill(0, 0, 255, 200);
  beginShape(TRIANGLES);
  vertex(-10, -10, -100); vertex(-10,  10, -100); vertex(0, 0, -108); // left side
  vertex( 10, -10, -100); vertex( 10,  10, -100); vertex(0, 0, -108); // right side
  vertex(-10, -10, -100); vertex( 10, -10, -100); vertex(0, 0, -108); // bottom side
  vertex(-10,  10, -100); vertex( 10,  10, -100); vertex(0, 0, -108); // top side
  endShape();

  // draw wings and tail fin in green
  fill(0, 255, 0, 200);
  beginShape(TRIANGLES);
  vertex(-100,  2, 30); vertex(0,  2, -80); vertex(100,  2, 30);  // wing top layer
  vertex(-100, -2, 30); vertex(0, -2, -80); vertex(100, -2, 30);  // wing bottom layer
  vertex(-2, 0, 98); vertex(-2, -30, 98); vertex(-2, 0, 70);  // tail left layer
  vertex( 2, 0, 98); vertex( 2, -30, 98); vertex( 2, 0, 70);  // tail right layer
  endShape();
  beginShape(QUADS);
  vertex(-100, 2, 30); vertex(-100, -2, 30); vertex(  0, -2, -80); vertex(  0, 2, -80);
  vertex( 100, 2, 30); vertex( 100, -2, 30); vertex(  0, -2, -80); vertex(  0, 2, -80);
  vertex(-100, 2, 30); vertex(-100, -2, 30); vertex(100, -2,  30); vertex(100, 2,  30);
  vertex(-2,   0, 98); vertex(2,   0, 98); vertex(2, -30, 98); vertex(-2, -30, 98);
  vertex(-2,   0, 98); vertex(2,   0, 98); vertex(2,   0, 70); vertex(-2,   0, 70);
  vertex(-2, -30, 98); vertex(2, -30, 98); vertex(2,   0, 70); vertex(-2,   0, 70);
  endShape();

  popMatrix();
}



// ================================
// YAW/HEADING GAUGE DISPLAY
// ================================
void drawYawGauge() {
  rectMode(CORNERS);
  textFont(font24);
  
  // draw yaw (heading) gauge, title, and value
  pushMatrix();
  translate(yawGaugeXPos, yawGaugeYPos);
  fill(255);
  text("Heading", 0, -gaugeSize/2 - 7);
  int heading = int(quadYaw);
  if (heading < 0) heading += 360;
  text(heading + "°", 0, gaugeSize/2 + 25);
  stroke(255);
  fill(50);
  ellipse(0, 0, gaugeSize, gaugeSize);
  rotate(radians(quadYaw));
  fill(255, 0, 0);
  noStroke();
  triangle(-5, 0, 0, -gaugeSize/2, 5, 0);
  fill(255);
  ellipse(0, 0, 12, 12);
  popMatrix();
}
 


// ================================
// PITCH GAUGE DISPLAY
// ================================
void drawPitchGauge() {
  rectMode(CORNERS);
  textFont(font24);

  // draw pitch gauge, title, and value
  pushMatrix();
  translate(pitchGaugeXPos, pitchGaugeYPos);
  fill(255);
  text("Pitch", 0, -gaugeSize/2 - 7);
  text(int(quadPitch) + "°", 0, gaugeSize/2 + 25);
  stroke(255);
  fill(50);
  ellipse(0, 0, gaugeSize, gaugeSize);
  translate(0, quadPitch/(180/gaugeSize));
  fill(255);
  noStroke();
  rect(-gaugeSize*cos(radians(quadPitch))/2, -1, gaugeSize*cos(radians(quadPitch))/2, 1);
  popMatrix();
}
 


// ================================
// ROLL GAUGE DISPLAY
// ================================
void drawRollGauge() {
  rectMode(CORNERS);
  textFont(font24);

  // draw roll gauge, title, and value
  pushMatrix();
  translate(rollGaugeXPos, rollGaugeYPos);
  fill(255);
  text("Roll", 0, -gaugeSize/2 - 7);
  text(int(quadRoll) + "°", 0, gaugeSize/2 + 25);
  stroke(255);
  fill(50);
  ellipse(0, 0, gaugeSize, gaugeSize);
  rotate(-radians(quadRoll));
  fill(0, 255, 0);
  noStroke();
  rect(-gaugeSize/2, -3, gaugeSize/2, 3);
  popMatrix();
}



// ================================
// JOYSTICK CONTROL BOX DISPLAY
// ================================
void drawJoybox() {
  noStroke();
  rectMode(CENTER);
  pushMatrix();
  translate(joyboxXPos, joyboxYPos);
  fill(255);
  stroke(0, 0, 255);
  rect(0, 0, joyboxSize, joyboxSize); // Roll Pitch Box Joystick Box 
  noStroke();
  
  if (joystick_active) // joystick is active
  {
      fill(150);
      rect(joy_x, 0, 2, joyboxSize); // vertical cross hair
      fill(255, 0, 0);
      rect(0, joy_y - 1, joyboxSize, 2); // horizontal cross hair
      fill(0, 0, 255);
      ellipse(joy_x, joy_y, 10, 10); // Joystick circle
  }
  else // joystick is inactive, zero.
  {
      fill(150);
      rect(0, 0, 2, joyboxSize); // vertical cross hair
      fill(255, 0, 0);
      rect(0, 0, joyboxSize, 2); // horizontal cross hair
      fill(0, 0, 255);
      ellipse(0, 0, 10, 10); // Joystick circle
  }
  
  textAlign(LEFT);
  textFont(font16b);
  fill(255, 0, 0); 
  text("X: " + (joy_x_out - 180), -joyboxSize/2, -joyboxSize/2 - 10);
  text("Y: " + (joy_y_out - 180), -joyboxSize/2 + 50, -joyboxSize/2 - 10);
  popMatrix();
}



// ================================
// THROTTLE CONTROL DISPLAY
// ================================
void drawThrottle() {
  rectMode(CENTER);
  textAlign(CENTER);
  textFont(font16b);
  pushMatrix();
  translate(throttleXPos, throttleYPos);
  fill(255);
  rect(0, 0, 10, throttleHeight); // Line behind THR meter
  fill(0, 0, 255);
  rect(0, throttleHeight/2 - (thr * (throttleHeight/99)), throttleWidth, 10); // THR meter
  fill(255, 0, 0);
  text("Throttle: " + thr_out + "%", 0, throttleHeight/2 + 25);
  popMatrix();
}



// ================================
// YAW CONTROL DISPLAY
// ================================
void drawYaw() {
  rectMode(CENTER);
  textAlign(CENTER);
  textFont(font16b);
  pushMatrix();
  translate(yawXPos, yawYPos);
  fill(255);
  rect(0, 0, yawWidth, 10); // line behind yaw meter
  fill(0, 0, 255);
  rect(yaw, 0, 10, 70);
  fill(255, 0, 0);
  String yaw_out_str = "Center";
  if (yaw_out == 0) yaw_out_str = "Rotate Left";
  else if (yaw_out == 2) yaw_out_str = "Rotate Right";
  text("Yaw: " + yaw_out_str, 0, yawHeight/2 + 25);
  popMatrix();
}



// ================================
// AVAILABLE SERIAL DATA EVENT
// ================================
void serialEvent(Serial whichPort) {
    rxString = whichPort.readString();
    String[] parts = split(trim(rxString), ',');
    if (parts[0].equals("o") && parts.length >= 4) {
        // received orientation data from quad
        quadYaw = float(parts[1]);
        quadRoll = float(parts[2]);
        quadPitch = float(parts[3]);
        //println(quadYaw + "," + quadPitch + "," + quadRoll); 
    } else if (parts[0].equals("f")) {
        // received FIFO overflow notification
        println("FIFO overflow");
        fifoFlag = 100; // display FIFO overflow notification until fifoFlag = 0
    } else if (parts[0].equals("k")) {
        // received command acknowledge from quad
        println("Quad acknowledged");
    } else {
        println("Unknown incoming data: '" + rxString + "'");
    }
}



// ================================
// KEY PRESSED EVENT
// ================================
void keyPressed()
{
  if (key == 'W' || key == 'w')
  {
    thrChange = 3;
  }
  if (key == 'S' || key == 's')
  {
    thrChange = -3;
  }
  if (key == 'a' || key == 'A')
  {
    //if(yaw <= 155)
    //{
      yaw = -200;
      yaw_out = 0;
    //}
    //else
    //{
     // yaw = yaw - 10; // add/subtract more to make the myquad more agressive
    //}  
  }  
  if (key == 'D' || key == 'd')
  {
    //if(yaw >= 534)
    //{
      yaw = 200;
      yaw_out = 2;
    //}
    //else
    //{
    //  yaw = yaw + 6;// add/subtract more to make the myquad more agressive
   // }
  }
  if (key == ' ')
  {
    // zero everything
    thr = 0;
    yaw = 0;
    yaw_out = 1;
  }
  if (keyCode == 37)
  {
    // left arrow
    joystick_active = true;
    joy_x = -joyboxSize/2;
  }
  if (keyCode == 38)
  {
    // up arrow
    joystick_active = true;
    joy_y = -joyboxSize/2;
  }
  if (keyCode == 39)
  {
    // right arrow
    joystick_active = true;
    joy_x = joyboxSize/2;
  }
  if (keyCode == 40)
  {
    // down arrow
    joystick_active = true;
    joy_y = joyboxSize/2;
  }
}



// ================================
// KEY RELEASED EVENT
// ================================
void keyReleased()
{
  if (key == 'W' || key == 'w')
  {
    thrChange = 0;
  }
  if (key == 'S' || key == 's')
  {
    thrChange = 0;
  }
  if (key == 'D' || key == 'd')
  {
    yaw = 0;
    yaw_out = 1;
  }
  if (key == 'a' || key == 'A')
  {
    yaw = 0;
    yaw_out = 1;
  }
  if (keyCode == 37)
  {
    // left arrow
    joystick_active = false;
    joy_x = 0;
  }
  if (keyCode == 38)
  {
    // up arrow
    joystick_active = false;
    joy_y = 0;
  }
  if (keyCode == 39)
  {
    // right arrow
    joystick_active = false;
    joy_x = 0;
  }
  if (keyCode == 40)
  {
    // down arrow
    joystick_active = false;
    joy_y = 0;
  }
}



// ================================
// MOUSE BUTTON PRESSED EVENT
// ================================
void mousePressed()
{
  if ((mouseX >= joyboxXPos - joyboxSize/2 && mouseX <= joyboxXPos + joyboxSize/2) &&
      (mouseY >= joyboxYPos - joyboxSize/2 && mouseY <= joyboxYPos + joyboxSize/2)) {
      joystick_active = true;
  }
}



// ================================
// MOUSE DRAGGED EVENT
// ================================
void mouseDragged() 
{
  if (joystick_active) {
    joy_x = mouseX - joyboxXPos;
    joy_y = mouseY - joyboxYPos;
  
    // make sure x and y are within [-size/2, +size/2] range
    
    if (joy_x < -joyboxSize/2) joy_x = -joyboxSize/2;
    else if (joy_x > joyboxSize/2) joy_x = joyboxSize/2;
  
    if (joy_y < -joyboxSize/2) joy_y = -joyboxSize/2;
    else if (joy_y > joyboxSize/2) joy_y = joyboxSize/2;
  }
}



// ================================
// MOUSE BUTTON RELEASED EVENT
// ================================
void mouseReleased() 
{
  joystick_active = false; // zero joystick input
  joy_y = 0; // joystick inputs
  joy_x = 0;
}



// ================================
// QUAD CONTROL STRING BUILDER
// ================================
String transmit_assit(int x, int y, int thr, int yaw)
{
  // 1XXXYYYTHRYAW 
  
  // actually:
  //   $XXXYYYTTY
  // where:
  //   $ = boundary byte
  //   XXX = 0-360 roll value
  //   YYY = 0-360 pitch value
  //   TT  = 0-99 throttle value
  //   Y   = 0-2 yaw adjustment value
  
  String x_str;
  String y_str;
  String thr_str;
  String yaw_str;
  
  if (x < 10)
  {
    x_str = ("00" + abs(x));
  }
  else if (x < 100)
  {
    x_str = ("0" + abs(x));
  }
  else
  {
    x_str = str(abs(x));
  }
  
  if (y < 10)
  {
    y_str = ("00" + abs(y));
  } 
  else if (y < 100)
  {
    y_str = ("0" + abs(y));
  }
  else
  {
    y_str = str(abs(y));
  }
  
  if (thr == 100)
  {
    thr_str = ("99");
  }
  else if (thr < 10)
  {
    thr_str = ("0" + thr);
  }
  else
  {
    thr_str = str(thr);
  }
  
  yaw_str = str(yaw);
 
  return ("$" + x_str + y_str + thr_str + yaw_out);
}
