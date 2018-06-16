#!/bin/bash

# EXAMPLE SCRIPT

# the temperature you want the extruder to be
# before turning off the machine (and fans)
SHUTDOWN_TEMP=40

# make sure bed and extruder are off
8settemp 0
8setbed 0

# message to display on LCD
8msg "Shut down at ${SHUTDOWN_TEMP} deg"

# quietly wait until extruder temp reaches 30deg C.
# changing this to '8alarm'  will make it beep when
# the set temperature is reached
8alarmq d t 30

# send shutdown instruction
8gcode "M81"

sudo shutdown -h now

