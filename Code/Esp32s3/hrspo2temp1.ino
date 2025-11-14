#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include "MAX30105.h"
#include "spo2_algorithm.h"
#include <Adafruit_MLX90614.h>
#include <math.h>

// OLED display setup
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET -1
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// Sensor objects
MAX30105 particleSensor;
Adafruit_MLX90614 mlx = Adafruit_MLX90614();

// Buffer for sensor data
#define BUFFER_SIZE 100
uint32_t irBuffer[BUFFER_SIZE];
uint32_t redBuffer[BUFFER_SIZE];

// Condition for finger detection
#define FINGER_ON 7000

// Validity flags
int32_t spo2;
int8_t spo2Valid;
int32_t heartRate;
int8_t heartRateValid;

// Moving average heart rate
const byte HR_SIZE = 8;
uint8_t hrRates[HR_SIZE] = {0};
byte hrSpot = 0;
int avgHR = 0;

// SpO2 and HR processing variables
int32_t irData, redData;
uint16_t bufferLength = BUFFER_SIZE;

void setup() {
  Serial.begin(115200);
  Wire.begin(13, 12);
  display.begin(SSD1306_SWITCHCAPVCC, 0x3C);
  display.display();
  delay(1000);

  // Initialize sensor
  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("MAX30105 not found");
    while (1);
  }
  particleSensor.setup(50, 4, 2, 400, 215, 16384);
  particleSensor.setPulseAmplitudeGreen(0);
  mlx.begin();
}

void loop() {
  // Fill sensor buffers
  for (size_t i = 0; i < BUFFER_SIZE; i++) {
    while (!particleSensor.available()) particleSensor.check();
    redBuffer[i] = particleSensor.getRed();
    irBuffer[i] = particleSensor.getIR();
    particleSensor.nextSample();
  }

  // Process HR & SpO2 
  maxim_heart_rate_and_oxygen_saturation(irBuffer, BUFFER_SIZE, redBuffer, &spo2, &spo2Valid, &heartRate, &heartRateValid);

  // Limit heart rate to a reasonable range (e.g., 20-220)
  if (heartRateValid && heartRate > 20 && heartRate < 220) {
    hrRates[hrSpot++] = (uint8_t)heartRate;
    hrSpot %= HR_SIZE;
    uint16_t sumHR = 0;
    for (byte i = 0; i < HR_SIZE; i++) sumHR += hrRates[i];
    avgHR = sumHR / HR_SIZE;
  } else {
  }

  // Read temperature
  float tempC = mlx.readObjectTempC();
  float tempF = mlx.readObjectTempF();

  // Determine if finger is placed
  long irValue = particleSensor.getIR();

  if (irValue > FINGER_ON) {
    // Valid measurements, display HR, SpO2, Temp
    display.clearDisplay();
    display.setTextSize(1);
    display.setTextColor(WHITE);
    display.setCursor(0, 5);
    display.print("Health Monitor");
    display.setTextSize(2);

    // Heart Rate display
    display.setCursor(0, 20);
    if (avgHR > 0) display.print(avgHR);
    else display.print("---");
    display.println(" BPM");

    // SpO2 display
    display.setCursor(0, 50);
    if (spo2Valid && (spo2 > 60 && spo2 <= 100)) display.print(String(spo2) + "%");
    else display.print("---- %");

    // Temperature display
    display.setTextSize(1);
    display.setCursor(80, 20);
    display.print("Temp:");
    display.setCursor(80, 35);
    display.print(tempC);
    display.println(" C");
    display.setCursor(80, 50);
    display.print(tempF);
    display.println(" F");
    display.display();

    // Serial output
    Serial.print("HR=");
    if (avgHR > 0) Serial.print(avgHR); else Serial.print("???");
    Serial.print(", SpO2=");
    if (spo2Valid && (spo2 > 0 && spo2 <= 100)) Serial.print(spo2); else Serial.print("???");
    Serial.print(", IR=");
    Serial.print(irValue);
    Serial.print(", Red=");
    Serial.print(redBuffer[BUFFER_SIZE/2]);
    Serial.print(", TempC=");
    Serial.println(tempC);

  } else {
    // No finger detected, show message
    for (byte i = 0; i < HR_SIZE; i++) hrRates[i] = 0;
    int sumHR = 0;
    for (byte i = 0; i < HR_SIZE; i++) sumHR += hrRates[i];
    avgHR = 0; // Reset average

    display.clearDisplay();
    display.setTextSize(2);
    display.setTextColor(WHITE);
    display.setCursor(30, 20);
    display.println("Place");
    display.setCursor(30, 50);
    display.println("Finger");
    display.display();
    Serial.println("Place finger");
  }
}
