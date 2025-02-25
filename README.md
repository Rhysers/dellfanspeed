# Dell Fan Speed Controller

## Overview
This script provides **dynamic fan speed control** for Dell R710 servers, using `ipmitool` to adjust fan speeds based on CPU temperatures. It integrates with **systemd** for automatic startup and monitoring.

### **Features**
- 🏎 **Dynamic Fan Control**: Adjusts fan speeds based on temperature thresholds.
- 🚀 **Prevents Rapid Cycling**: Implements a **cool-down delay** before lowering fan speeds.
- 🔧 **Systemd Integration**: Includes a **watchdog** to ensure the service is always running.
- 🔥 **Emergency Mode**: Automatically **maxes out fans** if the temperature exceeds **82°C**.
- 📄 **Logging**: Outputs fan speed changes and temperature readings to `/var/log/fanSpeed.log`.

---

## **Installation**

### **1. Install Dependencies**
```bash
sudo apt update && sudo apt install -y ipmitool lm-sensors systemd
```

### **2. Move the Script to `/opt`**
```bash
sudo mkdir -p /opt/fanController
sudo mv fanController.sh /opt/fanController/
sudo chmod +x /opt/fanController/fanController.sh
```

### **3. Install the Systemd Service**
Copy `fanController.service` (included in this repository) to the correct location:
```bash
sudo cp fanController.service /etc/systemd/system/
sudo systemctl daemon-reload
```

### **4. Enable and Start the Service**
```bash
sudo systemctl enable fanController
sudo systemctl start fanController
```

---

## **Usage & Monitoring**

### **Check Fan Controller Status**
```bash
sudo systemctl status fanController
```

### **View Logs**
```bash
sudo tail -f /var/log/fanSpeed.log
```

### **Force iDRAC to Take Over Again**
```bash
ipmitool raw 0x30 0x30 0x01 0x01
```

### **Test Watchdog Failure Handling**
1. Temporarily **comment out** `systemd-notify WATCHDOG=1` in the script.
2. Restart the service:  
   ```bash
   sudo systemctl restart fanController
   ```
3. Wait **30 seconds**—systemd should **detect the failure** and restart the service automatically.

### **Stop & Disable the Service**
```bash
sudo systemctl stop fanController
sudo systemctl disable fanController
```

---

## **Credits**
- **Original Author:** Rich Gannon  
- **Enhancements & Systemd Integration:** Rhys Ferris  
- **Contributions & Debugging Assistance:** ChatGPT  

---

## **Future Improvements**
✅ **Customizable Logging Levels**  
✅ **Support for Additional Dell Servers**  
✅ **More Fan Speed Profiles**  

Feel free to submit issues and contributions! 🚀  
