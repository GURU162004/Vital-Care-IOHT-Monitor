#include <WiFi.h>
#include <Wire.h>
#include <FirebaseClient.h>
#include <FirebaseESP32.h>
#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include "MAX30105.h"
#include "spo2_algorithm.h"
#include <Adafruit_MLX90614.h>

// OLED
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET -1
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// Sensors
MAX30105 particleSensor;
Adafruit_MLX90614 mlx = Adafruit_MLX90614();

// Firebase
#define WIFI_SSID "Wifi SSID"
#define WIFI_PASSWORD "Wifi Password"
#define API_KEY "Your API Key"
#define DATABASE_URL "Your Database URL"
#define USER_EMAIL "Your User Email"
#define USER_PASSWORD "User Password"

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

unsigned long lastSend = 0;
const unsigned long sendInterval = 10000; // 10 sec

// Finger detection
#define FINGER_ON 7000

// Buffers
#define BUFFER_SIZE 100
uint32_t irBuffer[BUFFER_SIZE];
uint32_t redBuffer[BUFFER_SIZE];

int32_t spo2, heartRate;
int8_t spo2Valid, heartRateValid;

const byte HR_SIZE = 8;
uint8_t hrRates[HR_SIZE] = {0};
byte hrSpot = 0;
int avgHR = 0;

void setup() {
  Serial.begin(115200);
  Wire.begin(13, 12);  // ESP32-S3 custom I2C pins

  // OLED setup
  display.begin(SSD1306_SWITCHCAPVCC, 0x3C);
  display.display();
  delay(1000);
  display.clearDisplay();

  // MAX30105 init
  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("MAX30105 not found");
    while (1);
  }
  particleSensor.setup(50, 4, 2, 400, 215, 16384);
  particleSensor.setPulseAmplitudeGreen(0);
  mlx.begin();

  // WiFi
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to Wi-Fi");
  while (WiFi.status() != WL_CONNECTED) {
    Serial.print(".");
    delay(300);
  }
  Serial.println("\nConnected!");

  // Firebase init
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
}

void loop() {
  for (size_t i = 0; i < BUFFER_SIZE; i++) {
    while (!particleSensor.available()) particleSensor.check();
    redBuffer[i] = particleSensor.getRed();
    irBuffer[i] = particleSensor.getIR();
    particleSensor.nextSample();
  }

  maxim_heart_rate_and_oxygen_saturation(irBuffer, BUFFER_SIZE, redBuffer, &spo2, &spo2Valid, &heartRate, &heartRateValid);

  if (heartRateValid && heartRate > 20 && heartRate < 220) {
    hrRates[hrSpot++] = heartRate;
    hrSpot %= HR_SIZE;
    uint16_t sumHR = 0;
    for (byte i = 0; i < HR_SIZE; i++) sumHR += hrRates[i];
    avgHR = sumHR / HR_SIZE;
  }

  float tempC = mlx.readObjectTempC();
  long irValue = particleSensor.getIR();

  display.clearDisplay();
  display.setTextColor(WHITE);
  if (irValue > FINGER_ON) {
    display.setTextSize(1);
    display.setCursor(0, 0);
    display.print("Vital Monitor");

    display.setTextSize(2);
    display.setCursor(0, 15);
    display.print("HR: ");
    if (avgHR > 0) display.print(avgHR); else display.print("---");

    display.setCursor(0, 35);
    display.print("SpO2: ");
    if (spo2Valid && spo2 > 60 && spo2 <= 100) display.print(spo2); else display.print("--");

    display.setTextSize(1);
    display.setCursor(80, 15);
    display.print("Temp:");
    display.setCursor(80, 30);
    display.print(tempC);
    display.print(" C");
  } else {
    for (byte i = 0; i < HR_SIZE; i++) hrRates[i] = 0;
    avgHR = 0;
    display.setTextSize(2);
    display.setCursor(30, 20);
    display.println("Place");
    display.setCursor(30, 45);
    display.println("Finger");
    }
  display.display();

  // Firebase send
  if (Firebase.ready() && millis() - lastSend > sendInterval && irValue > FINGER_ON) {
    lastSend = millis();
    Firebase.RTDB.setFloat(&fbdo, "vitals/values/remk/temperature", tempC);
    Firebase.RTDB.setInt(&fbdo, "vitals/values/remk/heartrate", avgHR);
    Firebase.RTDB.setInt(&fbdo, "vitals/values/remk/spo2", spo2);
    Serial.println("Uploaded to Firebase");
  }
}
