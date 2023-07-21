# How to join Twitch IRC w/ WeeChat
WeeChat terminal IRC client
- https://weechat.org

## gen token

1. acccess to "OAuth Password Generator"; semi-official service
 - https://twitchapps.com/tmi/
  - http://help.twitch.tv/customer/portal/articles/1302780-twitch-irc
2. push "Connect to Twitch"
3. copy oauth key
  - include "oauth:"

  ```
  oauth:***
  ```

 > https://twitchapps.com/tmi/#access_token=***&scope=chat_login

### reset/revoke
you must be keep "Twitch Chat OAuth Token Generator" connection

- http://www.twitch.tv/settings/connections

if you push "Disconnect", so IRC connection unavailable;
you have to need re-generate new oAuth key for join IRC

## add server
replace TWITCH_NAME to your lowercase Twitch Name

```
/server add twitch irc.twitch.tv/6667 -password=oauth:*** -nicks=TWITCH_NAME -username=TWITCH_NAME
```

> https://www.reddit.com/r/Twitch/comments/2uqews/anybody_here_using_weechat/

## connect and join

```
/connect twitch
```

```
/join #CHANNEL_NAME
```

## save settings
write settings to files

```
/save
```

## exit/close
exit channel

```
/part #CHANNEL_NAME
```

close WeeChat

```
/quit
```

## buffer
below commands/key very convenience when join 2 or more channels

```
/buffer list
```

### move buffer-ring
<kbd>Ctrl</kbd> + <kbd>n</kbd> , <kbd>Ctrl</kbd> + <kbd>p</kbd>

### close buffer
push <kbd>Tab</kbd> completion <code>BUFFER_NAME</code>

```
/buffer close BUFFER_NAME
```

### window split

**v**ertical and **h**orizontal split

```
/window splitv
/window splith
```

### move window
<kbd>F7</kbd> , <kbd>F8</kbd>

### undo split

```
/window merge
```

## set membership (optional)
use for normal IRC client; get user list et al.

```
/set irc.server.twitch.command "/quote CAP REQ :twitch.tv/membership"
```

> http://fogelholk.io/twitch-irc-joinsparts-with-weechat/
> https://ter0.net/enable-userlist-in-weechat-for-twitch-tv-irc/
