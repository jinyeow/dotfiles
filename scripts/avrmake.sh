#!/usr/bin/bash

#
# 28/09/2015
# Author: Jin-Yeow J Puah
#
# This was used in an Arch Linux environment.
# It uses avra which you can find here:
#   https://github.com/timofurrer/avra-atmega2560k
# and avrdude which can be downloaded from the Official Arch Repositories
#
# This is a simple script to compile and load AVR assembly files to the COMP2121
# board (arduino?).
# To run this without 'sudo avrdude' add user to uucp/lock/tty group(s):
#   gpasswd -a $USER [uucp/lock/tty]
#

# We are using Atmetl atmega2560
MCU=m2560
BAUDRATE=115200

# This is what the download.bat given by COMP2121 uses for the -c flag
PROGRAMMER=wiring

# This is the default on Arch Linux
USB=ttyACM0

# This is where I have my m2560def.inc
INCLUDE_PATH="/home/j1n/Dropbox/UNSW/2015 - First Year/Semester 2 - Spring/COMP2121/labs/asm/defines"

ASM_FILE=$1
HEX_FILE=$(echo $ASM_FILE | sed s/asm/hex/)

echo "[+] Assembling AVR code file [$ASM_FILE] ..."
avra -I "$INCLUDE_PATH" "$ASM_FILE"
sleep 3

echo "[+] Loading [$HEX_FILE] to COMP2121 board..."
avrdude -c "$PROGRAMMER" -p "$MCU" -b "$BAUDRATE" -P /dev/"$USB" -U flash:w:"$HEX_FILE":i -D
