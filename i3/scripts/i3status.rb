require 'json'
require 'i3ipc'

NAP_TIME = 5
if ARGV.size > 1
  NAP_TIME = ARGV[0].to_f
end

BLOCKS    = []
UL_PREV   = None
DL_PREV   = None
TIME_PREV = None
UL_NOW    = None
DL_NOW    = None
TIME_NOW  = Time.now

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
CMD_DISK_H     = 'df -hlP /home | grep /home'
CMD_DISK_R     = 'df -hlP / | grep /'
CMD_BRIGHT     = 'light -G'

def run(command)
  # what is the Ruby equivalent of Python Popen() ??
end

def try_catch(func)
  begin
    func.call
  rescue Exception => e
    msg = "Error #{e.to_s} @ #{func.to_s}"
    pack(msg, COLOR_URGENT)
  end
end

def pack(text, color)
  block = {
    'full_text' => text,
    'color' => color,
    'separator' => 'false',
    'separator_block_width' => 0
  }
  BLOCKS.append(block)
end

def disk_home
  disk = run(CMD_DISK_H)
  tokens = disk.split
  dir = tokens[-1]
  avail = tokens[-3]
  text = "#{dir} #{avail} free"
  block(ICON_RAM, text, COLOR_DISK)
end
