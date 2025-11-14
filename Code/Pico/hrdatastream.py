from machine import Pin, SoftI2C
import time
from max30102 import MAX30102, MAX30105_PULSE_AMP_MEDIUM

SDA_PIN = Pin(0)
SCL_PIN = Pin(1)
I2C_FREQ = 400000
FINGER_DETECT_THRESHOLD = 10000

# Control the data rate (~50 samples per second)
SAMPLE_DELAY_MS = 20

# --- 2. Main Program ---
def main():
    # --- Setup I2C and Sensor ---
    i2c = SoftI2C(sda=SDA_PIN, scl=SCL_PIN, freq=I2C_FREQ)

    sensor = MAX30102(i2c=i2c)
    if not sensor.i2c_address in i2c.scan():
        print("Sensor not found. Check wiring to GP8 and GP9.")
        return
    else:
        print("Sensor connected and recognized.")

    # Configure sensor
    sensor.setup_sensor()
    sensor.set_active_leds_amplitude(MAX30105_PULSE_AMP_MEDIUM)
    print("Starting data acquisition...")
    print("-" * 30)

    # --- Main Loop: Read and Stream Data ---
    while True:
        sensor.check()

        if sensor.available():
            # Get the raw IR and Red light values
            ir_reading = sensor.pop_ir_from_storage()
            red_reading = sensor.pop_red_from_storage()
            if ir_reading > FINGER_DETECT_THRESHOLD:
                # Print data in a comma-separated format for MATLAB
                print(f"{ir_reading},{red_reading}")

        time.sleep_ms(SAMPLE_DELAY_MS)

if __name__ == "__main__":
    main()
