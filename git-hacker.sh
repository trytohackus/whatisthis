#!/bin/bash

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

#trap - EXIT

declare -a def_opts=("localcopy" "ignoremode" "uploadurl" "copypath")
declare -A values=( [localcopy]="false" [ignoremode]="0" [uploadurl]="" [copypath]="" )
WORK_DIR="" # Temp folder, if used...

#       _                  __  __       _
#      / \   _ __  _ __   |  \/  | __ _(_)_ __
#     / _ \ | '_ \| '_ \  | |\/| |/ _` | | '_ \
#    / ___ \| |_) | |_) | | |  | | (_| | | | | |
#   /_/   \_\ .__/| .__/  |_|  |_|\__,_|_|_| |_|
#           |_|   |_|


function main()
{
  # Check if we have git installed...

  if ! type git &> /dev/null; then
    echo "You don't have git installed, please install it."
    return 0
  fi

  # First, we have to check if githack file doesn't exists to create default config.

  if [ ! -f githack ]; then
    create_def_config
  fi

  # Second, we have to make this file be ignored by the uploader.

  is_debug=false

  if [ -f "isdebug" ]; then
    is_debug=$(cat isdebug)
  fi

  ignore_this_file $is_debug

  # Third, we have to load values

  load_values

  # Fourth, on the execution depending in what the user said we have to do things...

  lc_var=${values[localcopy]}
  cp_var=${values[copypath]}

  readytocopy=false
  # Little chekc before we do anything

  lc_var=${lc_var,,} #Convert to lowercase
  if [[ $lc_var == "true" ]]; then
    if [[ -z $cp_var ]]; then
      echo "You must specify a path in case you set local copy as true."
      return 0 # Or continue without copying...
    else
      if [[ -d $cp_var ]]; then
        readytocopy=true
      else
        echo "Invalid copy path provided."
        return 0 #Or continue without copying...
      fi
    fi
  fi

  # Prepare everything in a new temp folder if cp_var is empty

  if [[ -z $cp_var ]]; then
    tn_file="$(pwd)/tempname"

    if [ ! -f $tn_file ]; then
      cp_var=$(create_temp_folder)
      echo "$(pwd)/$(basename $cp_var)"
      echo "Created temp folder in '$cp_var'."
      echo $cp_var > $tn_file
    else
      cp_var=$(cat $tn_file | head -n1)
    fi

    if [[ ! -d $cp_var ]]; then
      mkdir $cp_var
    fi

    readytocopy=true
  fi

  gitigpath="$cp_var"
  gitigpath+="/.gitignore"

  gitigcuspath=`pwd`
  gitigcuspath+="/githackignore"

  im_var=${values[ignoremode]}
  #echo "Selected option '$im_var' in ignore mode."

  case $im_var in
  "0")
    # We have to include all files, there is or there isn't .gitignore file
    # so, we need to upload to a temporaly folder or to copypath

    rm -rf $gitigpath
    ;;
  "1")
    # Don't do anything, if there isn't any .gitignore file we will do nothing
    ;;
  "2")
    if [[ ! -f $gitigcuspath ]]; then
      echo "You have specified to use a custom ignore file, please create githackignore with some content in this folder."
      return 0
    else
      # Copy githackignore file from this folder to another one
      cp $gitigcuspath "$cp_var/.gitignore"
    fi
    ;;
  *)
    echo "Unkown case '$im_var' for ignoremode."
    return 0
    ;;
  esac

  # Detect if we have to configure git before anything

  if [ -z $(git config --get user.name) ]; then
    echo "You need to configure GIT before doing anything..."
    return 0
  fi

  # Add temp folder to this .gitignore

  tmpfolder="/$(basename "$cp_var")/"

  if ! grep -q $tmpfolder ".gitignore"; then
    # Fix: New line is needed
    echo -e "$tmpfolder\n" >> ".gitignore"
  fi

  originhome=$(pwd) # We need to know how to go back to home
  uu_var=${values[uploadurl]}
  if [ -z $uu_var ]; then
    echo "Is very important that you specify an url to upload this content."
    return 0
  else
    # Check if the url is valid
    if curl --output /dev/null --silent --head --fail "$uu_var" && [[ $uu_var == *.git ]]; then
      # Depending if movied for first time or updated changes then commit or init or remote add

      repoexists=true

      if [[ ! -d "$cp_var/.git" ]]; then
        repoexists=false
        if [[ `git -C $cp_var ls-remote`="HEAD" ]] ; then
          # If this is true this means that the remote repo has content so, we will clone it, because...
          # Clone does the worm better if it already contains anything...
          git -C $cp_var clone $uu_var foo; mv $cp_var/foo/* $cp_var/foo/.git* $cp_var; rmdir $cp_var/foo
        else
          git init $cp_var
          git -C $cp_var remote add origin $uu_var
        fi
      fi

      # After we have assure all changes, copy inside the new ones...
      if [[ $readytocopy ]]; then
        smartcopy $cp_var $originhome
        yes | cp -rf $gitigcuspath "$cp_var/.gitignore" # Fix: we have to reupdate gitignore file...
      fi

      if [[ ! -z `git -C $cp_var diff HEAD .gitignore` ]]; then # Fixed unnecesary log errors, if gitignore have been changed then we have to re-add everything
        echo "Modified .gitignore file, updating cached files..."
        git -C $cp_var rm -rf --cached .
      fi

      read -p "Message for this commit: " commit_msg

      # Then with the new changes, we need to commit...
      git -C $cp_var add --all
      git -C $cp_var commit -m $commit_msg

      git -C $cp_var push -u origin master
    else
      echo "Invalid upload url provided."
      return 0
    fi
  fi
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

  if grep -q "git-hacker.sh" ".gitignore"; then
    #echo "This file is already in .gitignore"
    return 0
  fi

  line="\n"

  if [[ ${1,,} == "true" ]]; then
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
}

# deletes the temp directory
function cleanup
{
  rm -rf "$WORK_DIR"
  #echo "Deleted temp working directory $WORK_DIR"
}

function create_temp_folder
{
  # the directory of the script
  DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

  # the temp directory used, within $DIR
  # omit the -p parameter to create a temporal directory in the default location
  WORK_DIR=`mktemp -d -p $(pwd)` #"$DIR"`

  # check if tmp dir was created
  if [[ ! "$WORK_DIR" || ! -d "$WORK_DIR" ]]; then
    echo "Could not create temp dir"
    exit 1
  fi

  # register the cleanup function to be called on the EXIT signal
  trap cleanup EXIT

  #echo "$(pwd)/$(basename $WORK_DIR)"
  echo $WORK_DIR
}

# $1 = Where to copy
function smartcopy()
{
  # Added own executor
  ff=$(cat /proc/$PPID/cmdline)
  bindings=${ff:4}

  count=$(pwd | tr -cd '/' | wc -c)

  # Fix: Using -w to match whole foldername
  for file in $(find "$(pwd)" -type f | grep -v -e "tmp." -e "tempname" -e ".vs" -e $bindings -e $(basename $0) -e "githack" | grep -wv ".git" | cut -sd / -f $((count + 2))-); do 
    ffpath="$1/$file"
    ffold=$(dirname ${ffpath})

    #relpath=$(pwd | cut -sd / -f $((count + 2))-)
    if [ ! -d "$ffold" ]; then
      mkdir -p "$ffold/"
    fi
    
    cp -rf "$file" "$1/$file"
    
    #echo "$file"
    #echo "$(pwd)/$(basename $1)/$file"
  done
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