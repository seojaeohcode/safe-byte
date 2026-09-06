#include <Adafruit_NeoPixel.h>
const uint8_t LED_PIN=6, BUTTON_PIN=7, BUZZER_PIN=8;
Adafruit_NeoPixel pixels(16,LED_PIN,NEO_GRB+NEO_KHZ800);
char command[24]; uint8_t length=0;
bool lastReading=HIGH, stableReading=HIGH;
unsigned long changedAt=0, buzzerUntil=0;

void setState(const char* state) {
  uint32_t color=pixels.Color(0,0,0);
  if(!strcmp(state,"SAFE")) color=pixels.Color(0,80,30);
  else if(!strcmp(state,"DANGER")) { color=pixels.Color(100,0,0); buzzerUntil=millis()+1200; }
  else if(!strcmp(state,"CAUTION") || !strcmp(state,"ERROR")) { color=pixels.Color(80,45,0); buzzerUntil=millis()+300; }
  else if(!strcmp(state,"BUSY")) color=pixels.Color(0,30,80);
  if(!strcmp(state,"IDLE")) buzzerUntil=0;
  pixels.fill(color); pixels.show();
}
void setup() {
  Serial.begin(115200); pinMode(BUTTON_PIN,INPUT_PULLUP); pinMode(BUZZER_PIN,OUTPUT);
  pixels.begin(); pixels.setBrightness(50); setState("IDLE");
}
void loop() {
  while(Serial.available()) {
    char c=Serial.read();
    if(c=='\n') { command[length]=0; setState(command); length=0; }
    else if(c!='\r' && length<sizeof(command)-1) command[length++]=c;
  }
  bool reading=digitalRead(BUTTON_PIN);
  if(reading!=lastReading) { changedAt=millis(); lastReading=reading; }
  if(millis()-changedAt>40 && reading!=stableReading) {
    stableReading=reading;
    if(reading==LOW) Serial.println("SCAN");
  }
  digitalWrite(BUZZER_PIN, buzzerUntil && (long)(buzzerUntil-millis())>0 ? HIGH:LOW);
}
