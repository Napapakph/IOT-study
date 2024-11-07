#define BLYNK_PRINT Serial
#define BLYNK_TEMPLATE_ID "TMPL6XU6C-acw"
#define BLYNK_TEMPLATE_NAME "miniProject"
#define BLYNK_AUTH_TOKEN "iheu-cpy3IVs804DuwGuktembvinOc3e"
#define LINE_TOKEN "lrxdiZk9m9klIbKgn2ZkQWK0L8ne8PLKTAE7LzXEtHl"
#define LINE_ACCESS_TOKEN "G7f9sn+kLnnJNrc4/riPUs4plIwwNNStH3yLgkz84wkBNTZvuTVT48SQz+lAVZ6GQg3eS0rm7uIqGc2JGfiO7pSzcNQDNhWW8ZM25IwK7IVoYLiovG0x+Sq8g+N+FaotZSik+9UhH24wdvrD1T/gIgdB04t89/1O/w1cDnyilFU="

#include "SPI.h"
#include "Wire.h"
#include "Adafruit_GFX.h"
#include "Adafruit_SH1106.h"
#include "FS.h"

#include <WiFi.h>
#include <WiFiClient.h>
#include <HTTPClient.h>
#include <BlynkSimpleEsp32.h>
#include <EEPROM.h>
#include <LineNotify.h>
#include <ArduinoJson.h>
#include <WebServer.h>
#include <ESPAsyncWebServer.h>
#include <EmonLib.h> // ไลบรารีสำหรับ Energy Monitor
EnergyMonitor emon1; // สร้างอ็อบเจกต์สำหรับการวัดกระแสไฟฟ้า

#define EEPROM_SIZE 4096
#define COST_ADDR 0

#define OLED_RESET 4
#define SCREEN_WIDTH 128 // กำหนดความกว้างของหน้าจอ
#define SCREEN_HEIGHT 64 // กำหนดความสูงของหน้าจอ
Adafruit_SH1106 display(OLED_RESET);

LineNotify lineNotify(LINE_TOKEN);
const char *lineApiUrl = "https://api.line.me/v2/bot/message/reply";

//--------------------- กำหนดค่าตัวแปร-----------------------------------------

char ssid[] = "sssNy";     // DeeR_2.4G //sssNy
char pass[] = "s31122546"; // KaD29243 //s31122546
const char *serverName = "https://script.google.com/macros/s/AKfycbzfFHMw9xZUaYQzeLznhTLx9ZXumKr566AhDqNdjyuvyn-fxvyzWlC6h9ivcxUErNl4WA/exec";
WebServer server(8080); // กำหนดให้ ESP32 ทำหน้าที่เป็นเซิร์ฟเวอร์
AsyncWebServer asyncServer(8080);
unsigned long previousMillis = 0;
const unsigned long interval = 1000; // วัดทุก ๆ 1 วินาที
// float adc_value = 3200;
// const float V_esp32 = 3.3;
const int Voltage_home = 220;
const float powerFactor = 0.9; // ค่า Power Factor โดยประมาณสำหรับทั้งบ้าน
float V_out;
float I_real;
float I_rms;
float P;
float E;
float sum_E;
float ratePerKWh = 4.0; // อัตราค่าไฟฟ้า 4 บาทต่อหน่วย (kWh)
float cost = 0.0;
float sum_cost;
float limit_cost = 5000;
float new_limit_cost;
float energyValue;
float unit;
float cost_show;
float time_limit = 1 / 3600;
bool notifiedAtHalfLimit = false; // ใช้เพื่อตรวจสอบการแจ้งเตือนที่ 50%
bool notifiedAtFullLimit = false; // ใช้เพื่อตรวจสอบการแจ้งเตือนที่ 100%
BlynkTimer timer;

int state;
const int Set_up_Blynk = 0;
const int calculator = 1;
const int Read_Sensor = 2;
// const int Update_limit = 3;
const int Check_limit = 4;
const int Send_Alert = 5;
const int log_data = 6;

//-------------------------Sensor----------------------------------------------
const int sensorPin = 34;              // ขา ADC ของ ESP32 ที่เชื่อมต่อกับเซ็นเซอร์ SCT-013-000
const float VOLTAGE = 220.0;           // กำหนดแรงดันไฟบ้านคงที่ 220V (RMS)
const float offset = 1.44;             // ค่า Offset เพื่อชดเชยสัญญาณรบกวน
const float CALIBRATION_CONSTANT = 20; // ค่าคาลิเบรชันที่คำนวณไว้

//----------------------------ประกาศฟังก์ชันที่ใช้-----------------------------------
void calculate();
void saveCost_on_EEPROM();
void connect_Blynk();
void connect_Wifi();
void sendData();
void show_serial_monitor();
void delete_EEPROM();
void retrieveEnergyValue();
void handleGetData();
void replyToLine(const String &replyToken, const String &message);

// ฟังก์ชันคำนวณค่าปรับชดเชย
float adjustCurrent(float rawCurrent)
{
  // ตัวอย่างการสร้างสมการเส้นตรงจากค่าคู่ลำดับ
  return (0.89 * rawCurrent) + 0.5; // ค่าตัวคูณและตัวบวกสามารถปรับได้จากการทดลอง
}

void screen_oled()
{
  display.begin(SH1106_SWITCHCAPVCC, 0x3C);

  if (state == Set_up_Blynk)
  {
    display.clearDisplay();
    display.setTextSize(1.5);
    display.setTextColor(WHITE);
    display.setCursor(0, 5);

    display.println("WIFI Connected!");
    display.println("");
    display.setTextSize(1);
    display.print("WIFI :");
    display.println(ssid);
    display.println("");
    display.print("Pass");
    display.println(pass);
    display.setTextSize(0.5);
  }
  else if (state == calculator)
  {
    display.clearDisplay();
    display.setTextSize(1.5);
    display.setTextColor(WHITE);
    display.setCursor(0, 5);

    display.print("COST :");
    display.print(sum_cost);
    display.println("  bath");
    display.println("");
    display.setTextSize(1);
    display.print("POWER :");
    display.print(sum_E);
    display.print("  kWh.");
    display.println("");
    display.print("Unit :");
    display.print(ratePerKWh);
    display.println("  bath/unit");
    display.println("");
    display.print("Current :");
    display.print(I_real);
    display.println("  amp.");
    display.println("");
  }

  display.display();
}

void setup()
{
  // Debug console
  Serial.begin(115200);
  Serial.print("ESP32 IP Address: ");
  Serial.println(WiFi.localIP());
  emon1.current(sensorPin, CALIBRATION_CONSTANT); // กำหนดขาที่ใช้วัดและค่า Calibration ของเซ็นเซอร์ SCT-013-000
  connect_Wifi();
  connect_Blynk();
  screen_oled();
  timer.setInterval(10000L, sendData); // ส่งข้อมูลไปยัง Google Sheets ทุก 10 วินาที
  // ------- EEPROM -------------
  EEPROM.begin(EEPROM_SIZE); // เริ่มต้นการใช้งาน EEPROM
                             // delete_EEPROM();
  cost = EEPROM.readFloat(COST_ADDR);
  Serial.println("");
  Serial.print("Read cost from EEPROM: ");
  Serial.println(cost);

  retrieveEnergyValue();
  E = energyValue;
  // E=0;
  ratePerKWh = unit;
  sum_cost = cost_show;
  Serial.print("Read Energy from Sheets: ");
  Serial.println(E);
  Serial.print("Read ratePerKWh from Sheets: ");
  Serial.println(ratePerKWh);
  Serial.print("Read Cost from Sheets: ");
  Serial.println(sum_cost);

  sum_cost += cost;
  // sum_E += E;

  // ตรวจสอบว่าค่าที่อ่านได้จาก EEPROM ถูกต้องหรือไม่
  if (isnan(cost) || cost < 0)
  {             // กรณีที่ค่าใน EEPROM อาจไม่ถูกต้อง
    cost = 0.0; // ตั้งค่าเริ่มต้นใหม่เป็น 0
    Serial.println("Invalid EEPROM value detected, resetting cost to 0.0");
  }
  server.on("/getData", handleGetData); // กำหนดเส้นทางให้เรียก /getData ได้
  server.begin();

  state = Set_up_Blynk;
}

void loop()
{
  Blynk.run();
  server.handleClient(); // รอรับคำขอจากเซิร์ฟเวอร์
  timer.run();           // เรียกใช้งานฟังก์ชันที่ตั้งไว้ใน timer

  // เช็คสถานะการเชื่อมต่อกับ Blynk
  if (Blynk.connected())
  {
    Blynk.run(); // เรียกใช้งาน Blynk หากเชื่อมต่อสำเร็จ
    screen_oled();
  }
  else
  {
    Serial.println("Blynk disconnected!");
    // คุณอาจเพิ่มโค้ดสำหรับการเชื่อมต่อใหม่ได้ที่นี่ เช่น Blynk.connect()
  }
  screen_oled();
  //---------------------check state------------------------------------
  if (state == Set_up_Blynk)
  {

    screen_oled();
    state = Read_Sensor; // ตามจริงต้องส่งไป state Read_Sensor แต่อันนี้ทดลองก่อน
  }
  else if (state == Read_Sensor)
  {
    // อ่านค่า RMS ของกระแสไฟฟ้าจากเซ็นเซอร์และนำค่าไปปรับด้วยฟังก์ชัน adjustCurrent
    double amps = adjustCurrent(emon1.calcIrms(1480) - offset);

    // ป้องกันไม่ให้ค่ากระแสติดลบ (ตั้งค่าเป็น 0 หากน้อยกว่า 0)
    if (amps < 0)
      amps = 0;

    // คำนวณกำลังไฟฟ้า (Power) = Voltage * Current (RMS)
    I_real = amps;
    // float power = VOLTAGE * amps;

    // แสดงผลค่าแรงดันและกระแสที่คำนวณได้ใน Serial Monitor
    // แสดงค่าแรงดันในหน่วยโวลต์
    Serial.print(" Current: ");
    Serial.print(amps, 3); // แสดงค่ากระแสในหน่วยแอมป์
    Serial.print(" A, Power: ");

    delay(1000); // หน่วงเวลา 1 วินาทีเพื่ออ่านค่าทุก ๆ วินาที
    screen_oled();
    show_serial_monitor();
    state = calculator;
  }

  else if (state == calculator)
  {
    unsigned long currentMillis = millis();
    if (currentMillis - previousMillis >= interval)
    {
      previousMillis = currentMillis;
      calculate();
      screen_oled();
      state = Check_limit;
    }
  }
  else if (state == Check_limit)
  {
    screen_oled();
    if (limit_cost != 0)
    {

      if ((sum_cost >= (limit_cost * 0.5) && notifiedAtHalfLimit == false) || (sum_cost >= limit_cost && notifiedAtFullLimit == false))
      {
        state = Send_Alert;
      }
      else
      {
        state = log_data;
      }
    }
  }
  else if (state == log_data)
  {
    // cost += sum_cost;
    
    saveCost_on_EEPROM();
    sendData();
    delay(1000);
    state = Read_Sensor; // ตามจริงต้องส่งไป state Read_Sensor แต่อันนี้ทดลองก่อน
  }
  else if (state == Send_Alert)
  {
    if (limit_cost != 0)
    {

      if (sum_cost >= (limit_cost * 0.5) && notifiedAtHalfLimit == false)
      {
        int show_cost = limit_cost * 0.5;
        String message = "ค่าไฟเกิน: " + String(show_cost) + " บาทแล้วนะ อย่าลืมประหยัดไฟล่ะ!!";
        lineNotify.send(message.c_str()); // ส่งข้อความไปที่ไลน์
        Blynk.logEvent("temp_alert", message.c_str());
        notifiedAtHalfLimit = true; // ตั้งค่าสถานะว่าการแจ้งเตือนที่ 50% ได้ถูกส่งแล้ว
      }
      else if (sum_cost >= limit_cost && notifiedAtFullLimit == false)
      {
        int show_cost = limit_cost;
        String message = "ค่าไฟเกิน: " + String(show_cost) + " บาทแล้ว";
        lineNotify.send(message.c_str()); // ส่งข้อความไปที่ไลน์
        Blynk.logEvent("temp_alert", message.c_str());
        notifiedAtFullLimit = true; // ตั้งค่าสถานะว่าการแจ้งเตือนที่ 100% ได้ถูกส่งแล้ว
      }
    }
    state = log_data;
  }
}

//------------------------------connect Blynk ---------------------------------------------
void connect_Blynk()
{
  Blynk.begin(BLYNK_AUTH_TOKEN, ssid, pass);

  // รอการเชื่อมต่อและแสดงสถานะ
  Serial.print("Connecting to Blynk");
  if (!Blynk.connected())
  {
    Serial.print("Connecting to Blynk...");
    Blynk.connect(3000); // กำหนด timeout เป็น 3 วินาที
    if (Blynk.connected())
    {
      Serial.println("Connected to Blynk!");
    }
    else
    {
      Serial.println("Failed to connect to Blynk");
    }
  }
}

//------------------------------connect WIFI ----------------------------------------------
void connect_Wifi()
{
  WiFi.begin(ssid, pass);

  while (WiFi.status() != WL_CONNECTED)
  {
    delay(1000);
    Serial.println("Connecting to WiFi...");
  }
  Serial.println("Connected to WiFi");
}

// ------------------------------รับค่าจาก Blynk----------------------------------------------
/*
BLYNK_WRITE(V2)
{
  adc_value = param.asFloat(); // รับค่าจาก Virtual Pin V1 และเก็บใน tempThreshold
  Serial.print("New ADCESP32 threshold: ");
  Serial.println(adc_value);
}
*/

BLYNK_WRITE(V3)
{
  ratePerKWh = param.asFloat();
  Serial.print("Rate Per KWh: ");
  Serial.println(ratePerKWh);
}

BLYNK_WRITE(V5)
{
  time_limit = param.asFloat();
  Serial.print("Time hour : ");
  Serial.println(time_limit);
}

//----------------เปลี่ยน wifi --------------
BLYNK_WRITE(V6)
{
  String newSSID = param.asStr();          // รับค่า SSID ใหม่จาก Blynk
  newSSID.toCharArray(ssid, sizeof(ssid)); // แปลง String เป็น char array และเก็บใน ssid
  Serial.print("New SSID: ");
  Serial.println(ssid); // แสดงผล SSID ใหม่ทาง Serial Monitor
}
BLYNK_WRITE(V7)
{
  String newPass = param.asStr();
  newPass.toCharArray(pass, sizeof(pass));
  Serial.print("New Password: ");
  Serial.println(pass);
}

BLYNK_WRITE(V9)
{
  limit_cost = param.asFloat();
  Serial.print("New limit cost: ");
  Serial.println(limit_cost);

  notifiedAtHalfLimit = false;
  notifiedAtFullLimit = false;
}

//------------------------------------------------------------------------------------------------

void calculate()
{
  // สูตรแปลงค่า ADC เป็นแรงดันไฟฟ้าจริง V_out
  // V_out = (adc_value / 4095) * V_esp32;

  // สูตรแปลงค่า แรงดัน V_out เป็นกระแสจริง I_real
  // I_real = V_out / 2000;

  // สูตรคำนวณค่า I_rms จาก I_peak
  // I_rms = I_real / 1.414;

  // สูตรคำนวณพลังงานไฟฟ้า 𝑃
  P = Voltage_home * I_real * powerFactor;

  //  สูตรคำนวณพลังงานไฟฟ้าสะสม 𝐸
  // คำนวณพลังงานไฟฟ้าในหนึ่งวินาที(แปลงเป็น Wh โดยหาร 3600)
  E += (P / 3600.0); // หน่วยเป็น Wh
  sum_E = E;

  // คำนวณค่าไฟตามพลังงานสะสมในหน่วย kWh
  cost = (E / 1000.0) * ratePerKWh;

  sum_cost += cost;

  Blynk.virtualWrite(V0, ssid);
  Blynk.virtualWrite(V1, limit_cost);
  Blynk.virtualWrite(V2, ratePerKWh);
  Blynk.virtualWrite(V10, sum_E);

  delay(1000);
}

void saveCost_on_EEPROM()
{
  if (sum_cost > 5000)
  {
    sum_cost = 0;
    sum_E = 0;
  }
  Blynk.virtualWrite(V4, sum_cost);

  // ตรวจสอบว่าแต่ละตัวแปรไม่ใช่ NaN ก่อนการเขียนลง EEPROM
  if (!isnan(sum_cost))
  {
    EEPROM.writeFloat(COST_ADDR, sum_cost);
    EEPROM.commit();
    Serial.print("Cost saved to EEPROM: ");
    Serial.println(sum_cost);
  }
  else
  {
    Serial.println("Warning: sum_cost is NaN, skipping write to EEPROM");
  }
}

void sendData()
{
  if (WiFi.status() == WL_CONNECTED)
  {
    HTTPClient http;
    http.begin(serverName);
    http.addHeader("Content-Type", "application/x-www-form-urlencoded");

    // สร้างข้อมูลที่จะส่งไปยัง Google Sheets
    String httpRequestData = "sum_E=" + String(sum_E) + "&I_real=" + String(I_real) + "&cost=" + String(cost) + "&sum_cost=" + String(sum_cost) + "&ratePerKWh=" + String(ratePerKWh);

    while ((sum_E==sum_cost)&&(sum_E==sum_E)&&(cost==cost)&&(sum_cost==sum_cost)&&(ratePerKWh==ratePerKWh));


    // ส่งข้อมูลไปยัง Google Sheets
    int httpResponseCode = http.POST(httpRequestData);
    

    if (httpResponseCode == 200)
    {
      Serial.println("Data sent successfully");
    }
    else
    {
      Serial.print("Error sending data. HTTP Response code: ");
      Serial.println(httpResponseCode);
    }

    http.end();
  
    
  }
  else
  {
    Serial.println("WiFi Disconnected");
  }

  delay(1000); // ส่งข้อมูลทุก ๆ 1 นาที
}

void delete_EEPROM()
{
  EEPROM.writeFloat(COST_ADDR, 0.0); // ตั้งค่าเริ่มต้นของ cost เป็น 0.0

  EEPROM.commit(); // บันทึกการเปลี่ยนแปลงใน EEPROM จริง ๆ
  Serial.println("EEPROM has been cleared.");
}

void show_serial_monitor()
{
  Serial.println("----------------------------------------------------------------------------");
  Serial.print("I_real = ");
  Serial.println(I_real);

  Serial.print("Sum Energy = ");
  Serial.println(E);

  Serial.print("Cost = ");
  Serial.println(cost);

  Serial.print("Voltage_home = ");
  Serial.println(Voltage_home);

  Serial.print("powerFactor = ");
  Serial.println(powerFactor);

  Serial.print("sum_cost = ");
  Serial.println(sum_cost);
}

void retrieveEnergyValue()
{
  if (WiFi.status() == WL_CONNECTED)
  {
    HTTPClient http;
    http.begin(serverName);
    http.setFollowRedirects(HTTPC_STRICT_FOLLOW_REDIRECTS); // เพิ่มการติดตามการเปลี่ยนเส้นทาง
    int httpResponseCode = http.GET();

    if (httpResponseCode == 200)
    {
      String response = http.getString();
      Serial.println("Response: " + response);

      DynamicJsonDocument doc(1024);
      DeserializationError error = deserializeJson(doc, response);

      if (!error)
      {
        energyValue = doc["energy"];
        unit = doc["rate"];
        cost_show = doc["sum_cost"];
      }
      else
      {
        Serial.print("JSON Deserialization failed: ");
        Serial.println(error.c_str());
      }
    }
    else
    {
      Serial.print("HTTP Response Code: ");
      Serial.println(httpResponseCode);
    }
    http.end();
  }
  else
  {
    Serial.println("WiFi Disconnected");
  }
}
void handleGetData()
{
  String type = server.arg("type");

  DynamicJsonDocument doc(1024);

  if (type == "cost")
  {
    doc["cost_show"] = sum_cost;
  }
  else if (type == "energy")
  {
    doc["energy"] = sum_E;
  }

  String response;
  serializeJson(doc, response);

  server.send(200, "application/json", response);
}

void replyToLine(const String &replyToken, const String &message)
{
  HTTPClient http;
  http.begin("https://api.line.me/v2/bot/message/reply"); // URL สำหรับส่งข้อความกลับไปที่ Line
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Authorization", "Bearer " + String(LINE_ACCESS_TOKEN)); // ใช้ Access Token ในส่วน Header

  // สร้างข้อมูล JSON สำหรับส่งข้อความ
  String payload = "{\"replyToken\":\"" + replyToken + "\", \"messages\":[{\"type\":\"text\", \"text\":\"" + message + "\"}]}";

  // ส่งคำขอ HTTP POST พร้อมข้อมูล JSON
  int httpResponseCode = http.POST(payload);

  if (httpResponseCode > 0)
  {
    Serial.println("Message sent successfully!");
  }
  else
  {
    Serial.printf("Failed to send message. Error: %d\n", httpResponseCode);
  }

  http.end(); // ปิดการเชื่อมต่อ
}

