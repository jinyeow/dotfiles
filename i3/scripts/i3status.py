 # -*- coding: utf-8 -*-

from json import dumps
from subprocess import Popen, PIPE
from sys import argv, stdout
from time import sleep, time

NAP_TIME = 5
if len(argv) > 1:
    NAP_TIME = float(argv[1])

BLOCKS    = []
UL_PREV   = None
DL_PREV   = None
TIME_PREV = None
UL_NOW    = None
DL_NOW    = None
TIME_NOW  = time()

COLOR_STD       = '#f8f8f8'
COLOR_ICON      = '#1fc5ff'
COLOR_SEPARATOR = '#bb6900'
COLOR_URGENT    = '#f24444'

COLOR_TIME      = '#f8f8f8'
COLOR_DATE      = '#7cafc2'
COLOR_VOL       = '#9b44f2'
COLOR_BAT       = '#dddddd'
COLOR_BRIGHT    = '#e6ff5c'
COLOR_WIFI      = '#6acc6a'
COLOR_DISK      = '#ff765c'

ICON_SEPARATOR = '  '
ICON_TIME      = ' '
ICON_CALENDAR  = '  '
ICON_VOLUME    = ' '
ICON_BATTERY   = ' '
ICON_PLUG      = ' '
ICON_WIFI      = ' '
ICON_RAM       = ' '
ICON_CPU       = ' '
ICON_DOWN      = ' '
ICON_UP        = ''

ICON_VOL_HIGH  = ' '
ICON_VOL_MED   = ' '
ICON_VOL_LOW   = ' '
ICON_VOL_MUTE  = ' '
ICON_BRIGHT    = ' '
ICON_MAIL      = ' '

CMD_DATE       = 'date +"%a, %d %b %T"'
CMD_VOLUME     = 'amixer get Master | grep -o "[0-9]*%" | head -n1'
CMD_VOL_STATUS = 'amixer get Master | grep -o "[a-z]*" | tail -n1'
CMD_BATTERY    = 'acpi'
CMD_WIFI       = 'iwconfig wlp4s0 | grep -o "ESSID:\\".*\\"\|Quality=[0-9]\{1,3\}\|Rate=[0-9]\{1,3\}"'
CMD_DL_UPL     = 'cat /proc/net/dev | grep wlan0'
CMD_IP         = 'ifconfig eth0 | grep -o "inet addr:\\([1-9]\\+.\\)\\{4\\}"'
CMD_RAM        = 'free -m | grep "Mem:\|-/+"'
CMD_CPU        = 'sar 1 1 -P ALL | grep -o "\([0-9][0-9]:\?\)\{3\}[[:space:]]\+[0-9][[:space:]]\+[0-9]\+[.,][0-9]\+"'
CMD_DISK_H     = 'df -hlP /home | grep /home'
CMD_DISK_R     = 'df -hlP / | grep /'
CMD_BRIGHT     = 'light -G'

def run(command):
    call   = Popen(command, shell = True, stdout = PIPE)
    stdout = call.communicate()[0]
    return stdout.strip().decode('utf-8')

def try_catch(func):
    try:
        func()
    except Exception as e:
        msg = 'Error {0} @ {1}'.format(str(e), func.__name__)
        pack(msg, COLOR_URGENT)

def cpu():
    cpus  = run(CMD_CPU).split('\n')
    lines = [line.split() for line in cpus]
    sep()
    pack(ICON_CPU, COLOR_ICON)
    for i in range(len(cpus)):
        line = lines[i]
        perc = float(line[2].replace(',', '.'))
        load = '{:5.2f}%'.format(perc)
        load = '{:05.2f}%'.format(perc)
        pack(load, COLOR_STD if perc <= 80.0 else COLOR_URGENT)
        if i < len(cpus) - 1:
            pack(' | ', COLOR_STD)

def ram():
    ram  = run(CMD_RAM).split('\n')
    all  = ram[0].split()[1]
    used = ram[1].split()[2]
    text = '{0}/{1}MB'.format(used, all)
    block(ICON_RAM, text, COLOR_STD)

def disk_home():
    disk   = run(CMD_DISK_H)
    tokens = disk.split()
    dir    = tokens[-1]
    avail  = tokens[-3]
    text = '{} {} free'.format(dir, avail)
    block(ICON_RAM, text, COLOR_DISK)

def disk_root():
    disk   = run(CMD_DISK_R)
    tokens = disk.split()
    dir    = tokens[-1]
    avail  = tokens[-3]
    text   = '{} {} free'.format(dir, avail)
    block(ICON_RAM, text, COLOR_DISK)

def brightness():
    brightness = run(CMD_BRIGHT)
    block(ICON_BRIGHT, brightness, COLOR_BRIGHT)

def online():
    def net_snapshot():
        global UL_PREV, UL_NOW, DL_PREV, DL_NOW, TIME_PREV, TIME_NOW
        columns   = run(CMD_DL_UPL).split()
        UL_PREV   = UL_NOW
        DL_PREV   = DL_NOW
        TIME_PREV = TIME_NOW
        TIME_NOW  = time()
        time_diff = TIME_NOW - TIME_PREV
        DL_NOW    = float(columns[1])
        UL_NOW    = float(columns[9])
        DL_SPEED  = 0.0 if DL_PREV is None else (DL_NOW - DL_PREV) / 1024.0**2 / time_diff
        UL_SPEED  = 0.0 if UL_PREV is None else (UL_NOW - UL_PREV) / 1024.0**2 / time_diff
        return '{:1.2f} MB/s'.format(DL_SPEED), '{:1.2f} MB/s'.format(UL_SPEED)

    wifi = run(CMD_WIFI).split('\n')
    if len(wifi) > 1:
        ess_id  = wifi[0].strip().split(':')[1][1:-1]
        bitrate = wifi[1].strip().split('=')[1]
        quality = int(wifi[2].strip().split('=')[1]) * 1.4285
        # down, up = net_snapshot()
        # block(ICON_DOWN, down + ' ' + up, COLOR_STD)
        block(ICON_WIFI, '{:.0f}% @ {}, {} Mb/s'.format(quality, ess_id,
                                                        bitrate), COLOR_WIFI)

def battery():
    tokens    = run(CMD_BATTERY).split()
    perc_left = tokens[3] if len(tokens) == 4 else tokens[3][:-1]
    time_left = tokens[4] if len(tokens) != 4 else 'FULL'
    text      = '{}, {}'.format(perc_left, time_left)
    txt_color = COLOR_URGENT if int(perc_left[:-1]) <= 15 else COLOR_BAT
    block(ICON_BATTERY if tokens[2] == 'Discharging,' else ICON_PLUG, text, txt_color)

def date_time():
    date_time = run(CMD_DATE)
    splitInd  = date_time.rfind(' ')
    date      = date_time[:splitInd]
    time      = date_time[splitInd+1:]
    block(ICON_CALENDAR, date, COLOR_DATE)
    block(ICON_TIME, time, COLOR_TIME)

def volume():
    volume = run(CMD_VOLUME)
    status = run(CMD_VOL_STATUS)
    text = 'n/a' if volume == '' else volume
    perc = int(volume[0:-1])
    if perc > 85:
        icon = ICON_VOL_HIGH
    elif perc > 35:
        icon = ICON_VOL_MED
    elif perc > 0:
        icon = ICON_VOL_LOW
    else:
        icon = ICON_VOL_MUTE

    if status == 'off':
        text = 'mute'
        icon = ICON_VOL_MUTE
    block(icon, text, COLOR_VOL)

def pad(pre, text, post):
    if pre == 1:
        text = ' ' + text
    elif pre == 2:
        text = '  ' + text
    if post == 1:
        text += ' '
    elif post == 2:
        text += '  '
    return text

def block(icon, text, color):
    pack(ICON_SEPARATOR, COLOR_SEPARATOR)
    pack(icon, color)
    pack(text, color)

def sep():
    pack(ICON_SEPARATOR, COLOR_SEPARATOR)

def pack(text, color):
    block = {
        'full_text' : text,
        'color' : color,
        'separator' : 'false',
        'separator_block_width' : 0,
    }
    BLOCKS.append(block)

def main():
    global BLOCKS
    stdout.write('{"click_events": true, "version": 1}')
    stdout.write('[')
    stdout.write('[],')
    while True:
        for func in [brightness, disk_root, disk_home, online, battery, date_time, volume]:
            try_catch(func)
        pack(' ', COLOR_SEPARATOR)
        stdout.write(dumps(BLOCKS) + ',')
        stdout.flush()
        sleep(NAP_TIME)
        BLOCKS = []

if __name__ == '__main__':
    main()
