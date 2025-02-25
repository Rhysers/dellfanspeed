#!/bin/bash

#
# Dell R710 Fan Speed Controller
#
# Originally created by Rich Gannon <rich@richgannon.net>
# Updated copies of this program may be found at:
# http://richgannon.net/projects/dellfanspeed
#
# Edited & Enhanced by: Rhys Ferris <rhys@ferrisfam.net>
# Version 1.3: Added systemd watchdog support, cooldown timer, and improved logging
# - Implemented cooldown timer to prevent rapid fan cycling
# - Improved logging and fail-safes
#
# Additional Contributions by: ChatGPT (AI Assistance)
# - Debugging, optimization, and systemd integration guidance
#
# This program comes with absolutely no warranty.  
# Please test thoroughly on your hardware and in your environment  
# at your own risk.


MEGARAID=0
MEGACLI=0
DEBUG=1

SLEEP_TIMER=5
SLEEP_TIMER_MULTIPLY=6  # Delay before lowering fan speed (~30 sec)

TEMP_LEVELS=(30 33 36 39 42 45 48 50 52 54 56 58 60 62 64 66 68 70 75 80)
FAN_LEVELS=(0x0A 0x0E 0x12 0x1A 0x1A 0x1E 0x22 0x26 0x2A 0x2E 0x32 0x36 0x3A 0x3E 0x42 0x46 0x4A 0x4E 0x58 0x64)

EMERGENCY_TEMP=82
EMERGENCY_FAN=0x64

IPMI_TOOL="ipmitool"

OLD_LEVEL=0
FAN_IS_AUTO=1
CMD_FAN_AUTO=0
TIMER_MULTIPLY=0
CURRENT_FAN_SPEED=""
COOLDOWN_COUNT=0

#
# Function to determine appropriate fan level based on temp
#
determine_fan_speed() {
    local current_temp=$1
    local new_fan_speed=${FAN_LEVELS[0]}
    
    for i in $(seq 0 $((${#TEMP_LEVELS[@]} - 1))); do
        if [ $current_temp -ge ${TEMP_LEVELS[$i]} ]; then
            new_fan_speed=${FAN_LEVELS[$i]}
        else
            break
        fi
    done

    echo $new_fan_speed
}

#
# Trap SIGTERM to ensure iDRAC fan control is restored on exit.
#
trap exit_graceful SIGTERM

exit_graceful() {
    echo "Exit requested."
    echo "Enabling iDRAC automatic fan control."
    $IPMI_TOOL raw 0x30 0x30 0x01 0x01
    exit 0
}

echo "Setting fan control to manual mode."
$IPMI_TOOL raw 0x30 0x30 0x01 0x00

while true; do
    highest_temp=$(sensors | grep 'Core' | awk '{print substr($3,2,length($3)-5)}' | sort -nr | head -n1 | awk '{print int($1)}')
    
    if [ -z "$highest_temp" ]; then
        echo "Error: Could not read temperature. Skipping this cycle."
    else
        if [ $highest_temp -ge $EMERGENCY_TEMP ]; then
            if [ "$CURRENT_FAN_SPEED" != "$EMERGENCY_FAN" ]; then
                echo "Emergency condition! Setting fan speed to maximum ($EMERGENCY_FAN)"
                $IPMI_TOOL raw 0x30 0x30 0x02 0xff $EMERGENCY_FAN
                CURRENT_FAN_SPEED=$EMERGENCY_FAN
                COOLDOWN_COUNT=0
            fi
        else
            new_fan_speed=$(determine_fan_speed $highest_temp)
            
            if [ "$CURRENT_FAN_SPEED" != "$new_fan_speed" ]; then
                if [[ "$new_fan_speed" > "$CURRENT_FAN_SPEED" ]]; then
                    # Fan speed increasing → change immediately
                    echo "Temperature increased! Raising fan speed immediately."
                    echo "Setting fan speed to $new_fan_speed"
                    $IPMI_TOOL raw 0x30 0x30 0x02 0xff $new_fan_speed
                    CURRENT_FAN_SPEED=$new_fan_speed
                    COOLDOWN_COUNT=0
                else
                    # Fan speed decreasing → delay before lowering
                    if [[ "$COOLDOWN_COUNT" -lt "$SLEEP_TIMER_MULTIPLY" ]]; then
                        echo "Cooling delay in effect, maintaining current fan speed."
                        COOLDOWN_COUNT=$((COOLDOWN_COUNT + 1))
                    else
                        echo "Temperature stable, lowering fan speed."
                        echo "Setting fan speed to $new_fan_speed"
                        $IPMI_TOOL raw 0x30 0x30 0x02 0xff $new_fan_speed
                        CURRENT_FAN_SPEED=$new_fan_speed
                        COOLDOWN_COUNT=0
                    fi
                fi
            fi
        fi
    fi
    
    # Send systemd watchdog keep-alive signal
    systemd-notify WATCHDOG=1  

    sleep $SLEEP_TIMER
done
