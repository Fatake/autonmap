greenColour="\e[0;32m\033[1m";export greenColour;
redColour="\e[0;31m\033[1m";export redColour;
blueColour="\e[0;34m\033[1m";export blueColour;
lightblueColour="\e[0;34m\033[1;34m";export lightblueColour;
yellowColour="\e[0;33m\033[1m";export yellowColour;
purpleColour="\e[0;35m\033[1m";export purpleColour;
turquoiseColour="\e[0;36m\033[1m";export turquoiseColour;
grayColour="\e[0;37m\033[1m";export grayColour;
endColour="\033[0m\e[0m";export endColour;

function log_error() {
    printf "[${redColour}✘${endColour}] $@\n"
}
function log_warning() {
    printf "[${yellowColour}⚠${endColour}] $@\n"
}
function log_ok() {
    printf "[${greenColour}✓${endColour}] $@\n"
}
function log_info() {
    printf "[${lightblueColour}i${endColour}] $@\n"
}

function run_cmd () {
    /bin/bash -c "$1" 2>/dev/null
}

function chekRoot(){
  # Check if root launch
  if [ "$EUID" -ne 0 ]; then 
    log_error "Please run as root"
    log_info "check ./autonmap -h"
    exit 1
  fi
}