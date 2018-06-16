#!/bin/bash

# use this for symlinking all commands to the master command
# grep '^  8.*' _8control.sh |cut -d ')' -f 1|tr -d ' '|while read x; do ln -s _8control.sh $x; done

# based on Octoprint API documentation, http://docs.octoprint.org/en/master/api/index.html


CFGLOC=~/.octocmd.conf

OCTOHOST=`cat $CFGLOC|grep OctoPrint_URL | cut -d '"' -f 4`
OCTOKEY=`cat  $CFGLOC|grep OctoAPI_KEY   | cut -d '"' -f 4`

CURLOPT="--connect-timeout 3 -m 3"
VERBOSE=""

help(){
  echo "8control octoprint command suite, complementary to octocmd"
  echo ""
  echo "Global commands:"
  echo "  -h      this help"
  echo "  -v      verbose (show requests)"
  echo "  -vv     more verbose (show requests and headers)"
  echo ""
  grep '^ #8' "$0" |tr '#' ' '
}


if [ "$1" == "-h" ]; then help;exit 0; fi
if [ "$1" == "--help" ]; then help;exit 0; fi
if [ "$1" == "-v" ]; then VERBOSE=1; shift; fi
if [ "$1" == "-vv" ]; then VERBOSE=1; CURLOPT="$CURLOPT -i"; shift; fi


if [ "$OCTOHOST" = "" ]; then
  echo "Cannot find configuration."
  echo "Looking for '$CFGLOC' with format"
  echo '{'
  echo '    "OctoAPI_KEY": "0123456789ABCDEF0123456789ABCDEF",'
  echo '    "OctoPrint_URL": "http://1.2.3.4:5000"'
  echo '}'
  exit 1
fi


postjson(){
  if [ "$VERBOSE" ]; then echo "curl $CURLOPT -H \"X-Api-Key: $OCTOKEY\" -H \"Content-Type: application/json\" -X POST -d \"$2\" \"$OCTOHOST/$1\""; echo; fi
  s="`curl -s $CURLOPT -H "X-Api-Key: $OCTOKEY" -H "Content-Type: application/json" -X POST -d "$2" "$OCTOHOST/$1" 2>&1`"
  if [ "$s" ]; then echo "$s"; fi
}

posturlenc(){
  if [ "$VERBOSE" ]; then echo "curl $CURLOPT -H \"X-Api-Key: $OCTOKEY\" -H \"Content-Type: application/x-www-form-urlencoded\" -X POST -d \"$2\" \"$OCTOHOST/$1\""; echo; fi
  s="`curl -s $CURLOPT -H "X-Api-Key: $OCTOKEY" -H "Content-Type: application/x-www-form-urlencoded" -X POST -d "$2" "$OCTOHOST/$1" 2>&1`"
  if [ "$s" ]; then echo "$s"; fi
}

getmsg(){
  if [ "$VERBOSE" ]; then echo "curl $CURLOPT -H \"X-Api-Key: $OCTOKEY\" \"$OCTOHOST/$1\""; echo; fi
  s="`curl -s $CURLOPT -H "X-Api-Key: $OCTOKEY" "$OCTOHOST/$1" 2>&1`"
  if [ "$s" ]; then echo "$s"; fi
}

getstatus(){
  getmsg api/connection | grep '"state":'|cut -d '"' -f 4
}

sendg(){
  GCMD="`echo "$1" | tr '[a-z]' '[A-Z]'`"
  postjson api/printer/command '{ "command": "'"$GCMD"'" }'
}

CMD=`basename "$0"`

if [ "$VERBOSE" ]; then
  if [ "$CMD" == "8status" ]; then CMD="8status_raw";
  elif [ "$CMD" == "8gettemp" ]; then CMD="8gettemp_raw";
  elif [ "$CMD" == "8getbed" ]; then CMD="8getbed_raw";
  fi
fi


# use fixed format for facilitation of help and install:
# two spaces before command, for installer
# one space and hash for command help

case "$CMD" in
 #8checkcfg              check 8control's configuration
  8checkcfg)      echo "Octoprint host: $OCTOHOST"
                  echo "Octoprint API key: '$OCTOKEY'"
                  echo "Config file: '$CFGLOC'"
                  ;;

 #8apiver                show API and server version
  8apiver)        getmsg api/version  ;;
 #8statusraw             show controller connection status, raw JSON
  8status_raw)        getmsg api/connection  ;;
 #8status                show controller connection status, status only
  8status)        getstatus  ;;

 #8connect               connect controller to server
  8connect)       postjson api/connection '{ "command": "connect" }'  ;;
 #8disconnect            disconnect controller from server
  8disconnect)    postjson api/connection '{ "command": "disconnect" }'  ;;

  # todo: more commands into array
 #8g "<code>"            send gcode to controller
 #8gcode "<code>"        send gcode to controller
  8g|8gcode)      sendg "`echo "$@"`"  ;;

 #8g1 "<coords>"         send G1 command to controller
  8g1)            sendg "G1 `echo "$@"`"  ;;

 #8speed <factor>        override speed, in percents
  8speed)         sendg "M220 S$1";;
 #8feed <factor>         override filament feed, in percents
  8feed)          sendg "M221 S$1";;


 #8start                 start loaded print job
 #8print                 start loaded print job
  8start|8print)  postjson api/job '{ "command": "start" }'  ;;
 #8restart               restart print job
  8restart)       postjson api/job '{ "command": "restart" }'  ;;
  # todo: handle pausing toggle - pause just pauses, unpause unpauses
 #8pause_raw             pause/unpause running job, raw call
  8pause_raw)     postjson api/job '{ "command": "pause" }'  ;;
 #8pause                 pause running job
  8pause)         STATUS=`getstatus`
                  if [ "$STATUS" == "Printing" ]; then postjson api/job '{ "command": "pause" }'; fi  ;;
 #8resume                resume running job
  8resume)        STATUS=`getstatus`
                  if [ "$STATUS" == "Paused" ]; then postjson api/job '{ "command": "pause" }'; fi  ;;
 #8cancel                cancel running job
  8cancel)        postjson api/job '{ "command": "cancel" }'  ;;

 #8xcancel               cancel running job, keep temperature setting of the tools
  8xcancel)       TEMP0=`8gettemp|grep target:|head -n1|cut -d ':' -f 2`
                  TEMPB=`8getbed |grep target:|head -n1|cut -d ':' -f 2`
                  echo Cancelling job
                  8cancel
                  echo Setting tool and bed back to $TEMP0:$TEMPB
                  8settemp $TEMP0
                  8setbed $TEMPB
                  echo Homing
                  8home
                  ;;

 #8home                  home printer head
  8home)          postjson api/printer/printhead '{ "command": "home", "axes": [ "x","y","z"] }'  ;;
 #8jog <x> <y> <z>       jog printer head by x,y,z mm
 #8jog <z>               jog printer head by z mm
  8jog)           x=$1; y=$2; z=$3;
                  if [ "$y" == "" ]; then x=0;y=0;z=$1; fi
                  # invert the values to make the increments match the G1 position signs
                  if [ "${x:0:1}" == "-" ]; then x=${x:1}; else x=-$x; fi
                  if [ "${y:0:1}" == "-" ]; then y=${y:1}; else y=-$y; fi
                  if [ "${z:0:1}" == "-" ]; then z=${z:1}; else z=-$z; fi
                  postjson api/printer/printhead '{ "command": "jog", "x": '$x', "y": '$y', "z": '$z' }'  ;;

  # todo: handle more heads than just tool0
 #8settemp <temp>        set tool0 to <temp> 'C
  8settemp)       postjson api/printer/tool '{ "command": "target", "targets": { "tool0": '$1' } }'  ;;
 #8setbed <temp>         set bed to <temp> 'C
  8setbed)        postjson api/printer/bed  '{ "command": "target", "target": '$1' }'  ;;
 #8ex <mm>               extrude <mm> millimeters of filament (negative to retract)
 #8extrude <mm>          extrude <mm> millimeters of filament (negative to retract)
  8ex)            postjson api/printer/tool '{ "command": "extrude", "amount": '$1' }'  ;;
  8extrude)       postjson api/printer/tool '{ "command": "extrude", "amount": '$1' }'  ;;
 #8fex <mm> [mm/min]     fast extrude <mm> millimeters of filament (negative to retract) with optional speed
  8fex)           SP="$2"; if [ ! "$SP" ]; then SP=2000;fi
                  postjson api/printer/command '{ "commands": ["G91","G1 E'$1' F'$SP'","G90"] }'  ;;
# #8fastex <mm>    extrude <mm> millimeters of filament (negative to retract)
#  8fex)            postjson api/printer/tool '{ "command": "extrude", "amount": '$1' }'  ;;

#g91;g1 e500 f2000;g90

 #8fan <on|off|0..255>   control the head fan
  8fan)		  if [ "$1" == "on" ]; then sendg "M106 S255";
		  elif [ "$1" == "off" ]; then sendg "M107";
		  else sendg "M106 S$1";
		  fi;;

 #8gettemp_raw           show tool temperature
  8gettemp_raw)   getmsg api/printer/tool  ;;
 #8gettemp               show tool temperature
  8gettemp)       getmsg api/printer/tool | grep '  "'|tr -d '{}, "'  ;;
 #8getbed                show bed temperature, raw JSON
  8getbed_raw)    getmsg api/printer/bed  ;;
 #8getbed                show bed temperature
  8getbed)        getmsg api/printer/bed  | grep '  "'|tr -d '{}, "'  ;;

  # run the system command like from the menu
 #8run <cmd>             run system-menu command (see .octoprint/config.yaml for commands)
  8run)           posturlenc api/system "action=$1"  ;;

 #8ls_raw                list available files (raw JSON)
  8ls_raw)        getmsg api/files ;;
 #8ls                    list available files
  8ls)            getmsg api/files | grep "\"name\":" | cut -d '"' -f 4 ;;
 #8ll <filename>         show info for <filename> (raw JSON)
  8ll)            getmsg "api/files/local/$1"  ;;

 #8fselect <filename>    select <filename>
  8fselect)       postjson api/files/local/"$1" '{ "command": "select", "print": false }'  ;;

 #8getjob                information about current job, raw JSON
  8getjob)        getmsg /api/job;;

 #8msg "<msg>"           show message on display via M117 gcode
  8msg)           postjson api/printer/command '{ "command": "M117 '"$1"'" }'  ;;
 #8beep                  beep via M300 gcode
  8beep)          postjson api/printer/command '{ "command": "M300" }'  ;;

 #8alarm [d] <t|b> <T>   wait until <t>ip or <b>ed reaches temperature T ("d" for decreasing), then beep and exit
 #8alarmq [d] <t|b> <T>  wait until <t>ip or <b>ed reaches temperature T ("d" for decreasing), then quietly exit
  8alarm|8alarmq)
                  if [ "$1" == "d" ]; then comp="-le";comp2=">";shift;else comp="-ge";comp2="<";fi
                  if   [ "$1" == "t" ]; then tempcmd="8gettemp";tipno=1;tempend="tip"
                  elif [ "$1" == "b" ]; then tempcmd="8getbed"; tipno=1;tempend="bed"; else
                    echo -e "Unknown parameter '$1'.\nUsage: 8beep [d] <t|b> <temperature>\nWaits for <t>ip or <b>ed reaching temperature, optionally for [d]ecreasing, then beeps and exits."
                    exit 1
                  fi
                  while true; do
                    temp2=`$tempcmd |grep 'actual'|head -n $tipno|tail -n1|cut -d ':' -f 2`
                    temp=`echo $temp2 |cut -d '.' -f 1`
                    if [ $temp $comp $2 ]; then
                      echo "$tempend temperature $2'C reached.             ";if [ "$CMD" == "8alarm" ]; then 8beep;fi
		      exit 0;
                    fi
                    echo -en "$tempend temperature $temp2'C $comp2 $2'C, waiting...\r";sleep 2
                  done;;


  *)              echo "_8control.sh: unknown command '$CMD'."  ;;
esac


