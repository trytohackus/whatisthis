
#     _____ _____ _______   _    _          _____ _  ________ _____
#    / ____|_   _|__   __| | |  | |   /\   / ____| |/ /  ____|  __ \
#   | |  __  | |    | |    | |__| |  /  \ | |    | ' /| |__  | |__) |
#   | | |_ | | |    | |    |  __  | / /\ \| |    |  < |  __| |  _  /
#   | |__| |_| |_   | |    | |  | |/ ____ \ |____| . \| |____| | \ \
#    \_____|_____|  |_|    |_|  |_/_/    \_\_____|_|\_\______|_|  \_\

#       _                 __     __             
#      / \   _ __  _ __   \ \   / /_ _ _ __ ___ 
#     / _ \ | '_ \| '_ \   \ \ / / _` | '__/ __|
#    / ___ \| |_) | |_) |   \ V / (_| | |  \__ \
#   /_/   \_\ .__/| .__/     \_/ \__,_|_|  |___/
#           |_|   |_|                           

declare -a def_opts=("uploadmode" "copymode" "uploadurl" "copyfolder")
declare -A values=( [uploadmode]="0" [copymode]="0" [uploadurl]="" [copyfolder]="" )

#       _                  __  __       _       
#      / \   _ __  _ __   |  \/  | __ _(_)_ __  
#     / _ \ | '_ \| '_ \  | |\/| |/ _` | | '_ \ 
#    / ___ \| |_) | |_) | | |  | | (_| | | | | |
#   /_/   \_\ .__/| .__/  |_|  |_|\__,_|_|_| |_|
#           |_|   |_|                           


function main()
{
	# First, we have to check if githack file doesn't exists to create default config.

	if [ ! -f githack ]; then
		create_def_config
	fi

	# Second, we have to make this file be ignored by the uploader.

	ignore_this_file true

	# Third, we have to load values

	load_values
}

#       _                  _____                     
#      / \   _ __  _ __   |  ___|   _ _ __   ___ ___ 
#     / _ \ | '_ \| '_ \  | |_ | | | | '_ \ / __/ __|
#    / ___ \| |_) | |_) | |  _|| |_| | | | | (__\__ \
#   /_/   \_\ .__/| .__/  |_|   \__,_|_| |_|\___|___/
#           |_|   |_|                               

function create_def_config
{

	echo "[main]" > githack

	for i in "${def_opts[@]}"
	do
		echo "  $i = ${values[$i]}" >> githack
	done

}

# $1 = [bool] IsDebug?
function ignore_this_file()
{
	line=""

	if $1 ; then
		line+="!"
	fi

	line+="git-hacker.sh"
	filename=".gitignore"

	if [ ! -f $filename ]; then
		touch $filename
		echo "$line" > $filename
	else
		if ! grep -Fxq "$line" $filename ; then
			echo "$line" >> $filename
		fi
	fi
}

function load_values
{
	cfg_parser githack

	cfg_section_main

	for i in "${def_opts[@]}"; do
		# Default values

		#echo "Key: $i"
		#echo "Value: ${values[$i]}"
		eval "value=\$$i"
		values[$i]=$value
	done

	#Checking values

	#echo "----"

	#for j in "${!values[@]}"; do
	#	echo "Key: $j"
	#	echo "Value: ${values[$j]}"
	#done
}

#    ___ _   _ ___   ____
#   |_ _| \ | |_ _| |  _ \ __ _ _ __ ___  ___ _ __
#    | ||  \| || |  | |_) / _` | '__/ __|/ _ \ '__|
#    | || |\  || |  |  __/ (_| | |  \__ \  __/ |
#   |___|_| \_|___| |_|   \__,_|_|  |___/\___|_|
#

#
# based on http://theoldschooldevops.com/2008/02/09/bash-ini-parser/
#

PREFIX="cfg_section_"

function debug {
   if  ! [ -v "BASH_INI_PARSER_DEBUG" ]
   then 
      #abort debug
      return
   fi
   echo $*
   echo --start--
   echo "${ini[*]}"
   echo --end--
   echo
}

function cfg_parser {
   shopt -p extglob &> /dev/null
   CHANGE_EXTGLOB=$?
   if [ $CHANGE_EXTGLOB = 1 ]
   then
      shopt -s extglob
   fi
   ini="$(<$1)"                 # read the file
   ini=${ini//$'\r'/}           # remove linefeed i.e dos2unix

   ini="${ini//[/\\[}"
   debug "escaped ["
   ini="${ini//]/\\]}"
   debug "escaped ]"
   IFS=$'\n' && ini=( ${ini} )  # convert to line-array
   debug
   ini=( ${ini[*]/#*([[:space:]]);*/} )
   debug "remove ; comments"
   ini=( ${ini[*]/#*([[:space:]])\#*/} )
   debug "remove # comments"
   ini=( ${ini[*]/#+([[:space:]])/} ) # remove init whitespace
   debug
   ini=( ${ini[*]/%+([[:space:]])/} ) # remove ending whitespace
   debug "whitespace around ="
   ini=( ${ini[*]/*([[:space:]])=*([[:space:]])/=} ) # remove whitespace around =
   debug
   ini=( ${ini[*]/#\\[/\}$'\n'"$PREFIX"} ) # set section prefix
   debug
   ini=( ${ini[*]/%\\]/ \(} )   # convert text2function (1)
   debug
   ini=( ${ini[*]/=/=\( } )     # convert item to array
   debug
   ini=( ${ini[*]/%/ \)} )      # close array parenthesis
   debug
   ini=( ${ini[*]/%\\ \)/ \\} ) # the multiline trick
   debug
   ini=( ${ini[*]/%\( \)/\(\) \{} ) # convert text2function (2)
   debug
   ini=( ${ini[*]/%\} \)/\}} )  # remove extra parenthesis
   ini=( ${ini[*]/%\{/\{$'\n''cfg_unset ${FUNCNAME/#'$PREFIX'}'$'\n'} )  # clean previous definition of section 
   debug
   ini[0]=""                    # remove first element
   debug
   ini[${#ini[*]} + 1]='}'      # add the last brace
   debug
   eval "$(echo "${ini[*]}")"   # eval the result
   EVAL_STATUS=$?
   if [ $CHANGE_EXTGLOB = 1 ]
   then
      shopt -u extglob
   fi
   return $EVAL_STATUS
}

function cfg_writer {
   SECTION=$1
   OLDIFS="$IFS"
   IFS=' '$'\n'
   if [ -z "$SECTION" ] 
   then
      fun="$(declare -F)"
   else
      fun="$(declare -F $PREFIX$SECTION)"
      if [ -z "$fun" ]
      then
         echo "section $SECTION not found" >2
         exit 1
      fi
   fi
   fun="${fun//declare -f/}"
   for f in $fun; do
      [ "${f#$PREFIX}" == "${f}" ] && continue
      item="$(declare -f ${f})"
      item="${item##*\{}" # remove function definition
      item="${item##*FUNCNAME*$PREFIX\};}" # remove clear section
      item="${item/\}}"  # remove function close
      item="${item%)*}" # remove everything after parenthesis
      item="${item});" # add close parenthesis
      vars=""
      while [ "$item" != "" ]
      do
         newvar="${item%%=*}" # get item name
         vars="$vars $newvar" # add name to collection
         item="${item#*;}" # remove readed line
      done
      eval $f
      echo "[${f#$PREFIX}]" # output section
      for var in $vars; do
         eval 'local length=${#'$var'[*]}' # test if var is an array
         if [ $length == 1 ]
         then
            echo $var=\"${!var}\" #output var
         else 
            echo ";$var is an array" # add comment denoting var is an array
            eval 'echo $var=\"${'$var'[*]}\"' # output array var
         fi
      done
   done
   IFS="$OLDIFS"
}

function cfg_unset {
   SECTION=$1
   OLDIFS="$IFS"
   IFS=' '$'\n'
   if [ -z "$SECTION" ] 
   then
      fun="$(declare -F)"
   else
      fun="$(declare -F $PREFIX$SECTION)"
      if [ -z "$fun" ]
      then
         echo "section $SECTION not found" >2
         return
      fi
   fi
   fun="${fun//declare -f/}"
   for f in $fun; do
      [ "${f#$PREFIX}" == "${f}" ] && continue
      item="$(declare -f ${f})"
      item="${item##*\{}" # remove function definition
      item="${item##*FUNCNAME*$PREFIX\};}" # remove clear section
      item="${item/\}}"  # remove function close
      item="${item%)*}" # remove everything after parenthesis
      item="${item});" # add close parenthesis
      vars=""
      while [ "$item" != "" ]
      do
         newvar="${item%%=*}" # get item name
         vars="$vars $newvar" # add name to collection
         item="${item#*;}" # remove readed line
      done
      for var in $vars; do
         unset $var
      done
   done
   IFS="$OLDIFS"
}

function cfg_clear {
   SECTION=$1
   OLDIFS="$IFS"
   IFS=' '$'\n'
   if [ -z "$SECTION" ] 
   then
      fun="$(declare -F)"
   else
      fun="$(declare -F $PREFIX$SECTION)"
      if [ -z "$fun" ]
      then
         echo "section $SECTION not found" >2
         exit 1
      fi
   fi
   fun="${fun//declare -f/}"
   for f in $fun; do
      [ "${f#$PREFIX}" == "${f}" ] && continue
      unset -f ${f}
   done
   IFS="$OLDIFS"
}

function cfg_update {
   SECTION=$1
   VAR=$2
   OLDIFS="$IFS"
   IFS=' '$'\n'
   fun="$(declare -F $PREFIX$SECTION)"
   if [ -z "$fun" ]
   then
      echo "section $SECTION not found" >2
      exit 1
   fi
   fun="${fun//declare -f/}"
   item="$(declare -f ${fun})"
   #item="${item##* $VAR=*}" # remove var declaration
   item="${item/\}}"  # remove function close
   item="${item}
    $VAR=(${!VAR})
   "
   item="${item}
   }" # close function again

   eval "function $item"
}

#Test harness
if [ $# != 0 ]
then
   $@
fi
# vim: filetype=sh

### CALL MAIN ###

main

###  END CALL ###
