#!/bin/bash

greenColour="\e[0;32m\033[1m";export greenColour;
redColour="\e[0;31m\033[1m";export redColour;
blueColour="\e[0;34m\033[1m";export blueColour;
lightblueColour="\e[0;34m\033[1;34m";export lightblueColour;
yellowColour="\e[0;33m\033[1m";export yellowColour;
purpleColour="\e[0;35m\033[1m";export purpleColour;
turquoiseColour="\e[0;36m\033[1m";export turquoiseColour;
grayColour="\e[0;37m\033[1m";export grayColour;
endColour="\033[0m\e[0m";export endColour;

log_error() {
  printf "[${redColour}✘${endColour}] $@\n"
}
log_warning() {
  printf "[${yellowColour}⚠${endColour}] $@\n"
}
log_ok() {
  printf "[${greenColour}✓${endColour}] $@\n"
}
log_info() {
  printf "[${lightblueColour}i${endColour}] $@\n"
}

run_cmd () {
  /bin/bash -c "$1" 2>/dev/null
}

chekRoot(){
  # Check if root launch
  if [ "$EUID" -ne 0 ]; then 
    log_error "Please run as root"
    log_info "check ./autonmap -h"
    exit 1
  fi
}

usage(){
  echo "${greenColour}================================================================================";
  echo "====================================   USAGE   =================================";
  echo "================================================================================${endColour}";
  log_info "autonmap is designed to run a full TCP/IP host discovery, scaning and firgerprinting"
  echo "Usage:"
  echo -e "${redColour}sudo${endColour} ./autonmap -o <output_files> -t <target>\n\n"
  echo -e "\t-h \tDisplays this message of use"
  echo -e "\t-o \tFile name to use to save scan related files"
  echo -e "\t-t \tTarget IP,CIDR or pass an input file as \"-iL file.lst\" to scan more complex ranges\n\n";
  echo -e "\t-d \tPerform Host Discovery only"
  log_warning "This script is only a wrapper for bash evals, so, use parameters with care!"
}

host_discover(){

  #Host discovery on top TCP and UDP ports
  TCPPORTS="80,443,22,3389,1723,8080,3306,135,53,143,139,445,110,25,21,23,5432,27017,1521"
  UDPPORTS="139,53,67,135,445,1434,138,123,137,161,631"
  FIREWALLEVASION="--randomize-hosts"

  FLAGS="-sn -PE -PP -PM -PS${TCPPORTS} -PA${TCPPORTS} -PU${UDPPORTS} -PO ${FIREWALLEVASION}"

  OUT_FILE="-oA ${SAVE_DIR}/${NAME}_alive_hosts"

  NMAP_COMMAND="nmap ${FLAGS} ${OUT_FILE} ${TARGET} ";
  echo "================================================================================";
  echo -e "==========================  ${purpleColour}H O S T    D I S C O V E R Y${endColour}  ======================";
  echo "================================================================================";
  echo -e "command# ${greenColour}${NMAP_COMMAND}${endColour}";
  echo -e "================================================================================\n";
  eval $NMAP_COMMAND

  #Extract list of alive hosts
  cat "${SAVE_DIR}/${NAME}_alive_hosts.gnmap" | grep "Status: Up" | cut -d " " -f 2 > "${SAVE_DIR}/${NAME}_hosts".lst;
}

syn_port_discover(){
  #Fast full port scan with 65535 tcp ports and top UDP
  TCPPORTS="1-65535"
  UDPPORTS="7,9,11,13,17,19,37,49,53,67-69,80,88,111,120,123,135-139,158,161-162,177,213,259-260,427,443,445,464,497,500,514-515,518,520,523,593,623,626,631,749-751,996-999,1022-1023,1025-1030,1194,1433-1434,1645-1646,1701,1718-1719,1812-1813,1900,2000,2048-2049,2222-2223,2746,3230-3235,3283,3401,3456,3703,4045,4444,4500,4665-4666,4672,5000,5059-5061,5351,5353,5632,6429,7777,8888,9100-9102,9200,10000,17185,18233,20031,23945,26000-26004,26198,27015-27030,27444,27960-27964,30718,30720-30724,31337,32768-32769,32771,32815,33281,34555,44400,47545,49152-49154,49156,49181-49182,49186,49190-49194,49200-49201,49211,54321,65024"

  RRT="--min-rtt-timeout 500ms --max-rtt-timeout 2000ms --initial-rtt-timeout 750ms --defeat-rst-ratelimit"
  RATE="--min-rate 3000 --max-rate 8000"
  TIMING="-T4 --max-retries 2 ${RRT} ${RATE} --disable-arp-ping"
  FIREWALLEVASION="--randomize-hosts"

  FLAGS="-Pn -n -sS -sU -p T:${TCPPORTS},U:${UDPPORTS}"

  INPUT_FILE="-iL ${SAVE_DIR}/${NAME}_hosts.lst"
  OUT_FILE="-oA ${SAVE_DIR}/${NAME}_syn_scan"

  NMAP_COMMAND="nmap ${FLAGS} ${TIMING} ${FIREWALLEVASION} ${OUT_FILE} ${INPUT_FILE}";
  echo -e "\n\n================================================================================";
  echo -e "================================  ${purpleColour}S Y N   S C A N${endColour}  =============================";
  echo "================================================================================";
  echo -e "command# ${greenColour}${NMAP_COMMAND}${endColour}";
  echo -e "================================================================================\n";
  eval $NMAP_COMMAND;
}

script_version_scan(){
  #Extract open ports list trimming ending comma
  TCPPORTS=$(cat "${SAVE_DIR}/${NAME}_syn_scan.gnmap" | awk -F " " '{ s = ""; for (i = 4; i <= NF; i++) s = s $i " "; print s }' | tr ", " "\n" | grep open | grep tcp | cut -d "/" -f 1 | sort -nu | paste -s -d, - );
  UDPPORTS=$(cat "${SAVE_DIR}/${NAME}_syn_scan.gnmap" | awk -F " " '{ s = ""; for (i = 4; i <= NF; i++) s = s $i " "; print s }' | tr ", " "\n" | grep open | grep udp | cut -d "/" -f 1 | sort -nu | paste -s -d, - );

  FLAGS="-Pn -n -sS -sU -sCV -A -T4"

  INPUT_FILE="-iL ${SAVE_DIR}/${NAME}_hosts.lst"
  OUT_FILE="-oA ${SAVE_DIR}/${NAME}_service_scan"
  #Final scan full connect and service reconnaissance if<>fi sentece to handle empty strings and keep command integrity
  if [ -z "${TCPPORTS}" ]; then
    TCPPORTS="22,80,443"
  fi

  NMAP_COMMAND="nmap ${FLAGS} -p T:${TCPPORTS},U:${UDPPORTS} ${FIREWALLEVASION} ${OUT_FILE} ${INPUT_FILE}";
  echo -e "\n\n================================================================================";
  echo -e "===========================   ${purpleColour}S C R I P T    S C A N${endColour}   =========================";
  echo "================================================================================";
  echo -e "command# ${greenColour}${NMAP_COMMAND}${endColour}";
  echo -e "================================================================================\n";
  eval $NMAP_COMMAND;
}

generate_report(){
  NMAP_BOOTSTRAP_PATH="$(pwd)/nmap-bootstrap.xsl/nmap-bootstrap.xsl"

  if [ ! -e "$NMAP_BOOTSTRAP_PATH" ]; then
    NMAP_BOOTSTRAP_PATH="/opt/autonmap/nmap-bootstrap.xsl/nmap-bootstrap.xsl"
  fi

  if [ ! -e "$NMAP_BOOTSTRAP_PATH" ]; then
    NMAP_BOOTSTRAP_PATH="/opt/nmap-bootstrap-xsl/nmap-bootstrap.xsl"
  fi

  REPORT="xsltproc -o ${SAVE_DIR}/${NAME}_report.html ${NMAP_BOOTSTRAP_PATH} ${SAVE_DIR}/${NAME}_service_scan.xml"
  echo -e "\n\n================================================================================";
  echo -e "=================================   ${purpleColour}REPORTING${endColour}   ================================";
  echo "================================================================================";
  echo -e "command# ${greenColour}${REPORT}${endColour}";
  echo -e "================================================================================\n";
  if [ ! -e "$NMAP_BOOTSTRAP_PATH" ]; then
    COMMAND="git clone --quiet https://github.com/honze-net/nmap-bootstrap-xsl.git /opt/nmap-bootstrap-xsl"
    run_cmd "$COMMAND"
  fi
  log_ok "Report Generated Successfully"
  eval $REPORT
}

# Check opts
while getopts ":t:o:hd" opt; do
  case $opt in
    # help
    h)
      usage
      exit 1
      ;;

    # Target
    t)
      TARGET="$OPTARG"
      f_target=true
      ;;

    # output file
    o)
      NAME="$OPTARG"
      f_name=true
      ;;

    d)
      log_info "Host Discovery only"
      echo -e "${redColour}================================================================================${endColour}";
      f_hostdiscoveronly=true
      ;;

    \?)
      log_error "Invalid option:\t -$OPTARG" >&2
      exit 1
      ;;

    :)
      log_error "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

chekRoot

# check that output and target is not empty
if [ -z "$f_name" ] || [ -z "$f_target" ]; then
  log_error "ERROR! check ./autonmap -h"
  exit 1;
fi

FLAG="-iL"
if [[ "$TARGET" == *"-iL"* ]]; then
  FILE_NAME=${TARGET//$FLAG/}
  TRGS=$(echo $(cat $FILE_NAME) | tr ' ' ',')
  log_ok "File:\t\t${FILE_NAME}"
  log_info "Targets:\t\t ${TRGS}" 
else
  log_info "Target:\t\t $TARGET" 
fi

log_info "Output Files:\t $NAME" 

SAVE_DIR="autonmap_${NAME}"
if [ ! -d "${SAVE_DIR}" ]; then
  log_info "Creating directory: ${SAVE_DIR}...\n"
  /bin/bash -c "mkdir ${SAVE_DIR}/" 2>/dev/null
  /bin/bash -c  "chown -R 1000:1000 ${SAVE_DIR}/" 2>/dev/null
fi

if [ "$f_hostdiscoveronly" = "true" ] ; then
  host_discover
  /bin/bash -c  "chown -R 1000:1000 ${SAVE_DIR}/" 2>/dev/null
  echo ""
  log_ok "D O N E \n"
  exit 1
fi
host_discover

syn_port_discover

script_version_scan

generate_report

/bin/bash -c  "chown -R 1000:1000 ${SAVE_DIR}/" 2>/dev/null
log_ok "D O N E \n"
