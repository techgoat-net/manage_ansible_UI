#!/usr/bin/env bash
# set -x
#
# Titel      : install_ansible_virtualdev_menu.sh
# Description: Listet vorhanden Ansible-Instanzen per Menue auf und erstellt auf Wunsch neue Versionen
#
# Autor : rasputin
# Date  : 2019-02-22
# ----------------------------------------------------------------------------------------------
# modified: rasputin 2019-02-22 initiales Sript erstellt
# modified: rasputin 2019-02-23 Kommentare hinzugefügt, Farben hinzugefügt uns angepasst, installation developer Version hinzugefügt

### Defaultwerte ###
DEFAULTUSER="rasputin"
DEFAULTPATH="/home/$DEFAULTUSER/Ansible"
DEFAULTANSIBLEVERSION="2.7.0"
GREEN='\e[32m'     
RED='\e[31m'
RESET='\e[0m'   
DEVINSTALLDIR="${DEFAULTPATH}/ansible_dev"
######

# Dieses Scriot sollte nur als einfacher Benutzer ausgeführt werden
if [ "$EUID" -eq 0 ]; then  
  echo -e "${RED}[!]${RESET} Bitte nicht als root ausfuehren"  
  exit 1 
fi 

# Arrays start at 0!
STARTNUM=0

# Auslesen des Verzeichnisses (per for-loop)  und auflisten der verfügbaren Ansible-Versionen
# Hierbei wird ein Array angelegt, wobei "STARTNUM" der INDEX ist und die gefundene Ansible-Version der entsprechende Value-Wert
for i in $(find $DEFAULTPATH -maxdepth 2 -type d -iname 'ansible_*' | awk -F '/' '{print $NF}'); do echo -e "[${GREEN}$STARTNUM${RESET}]: $i";arr[$STARTNUM]=$i; STARTNUM=$(( STARTNUM+1 )); done

# Option "neue Ansible Version anlegen 
echo -e "[${GREEN}${STARTNUM}${RESET}]: Eine neue Ansible Version installieren";arr[${STARTNUM}]="neue_version";STARTNUM=$(( STARTNUM+1 ))
# Die aktuelle Developer-Version wird installiert, bei jeder Ausführung wird neu das git-Repo geklont und damit gearbeitet
echo -e "[${GREEN}${STARTNUM}${RESET}]: Die aktuellste Developer Version installieren";arr[${STARTNUM}]="install_dev";STARTNUM=$(( STARTNUM+1 ))
# Abbruch-Option eingebaut
echo -e "[${RED}$STARTNUM${RESET}]: Abbruch";arr[$STARTNUM]="ende"
# Abfrage der gewünschten Option
echo -e "Option?"
# Eingabe wird nicht weiter angezeigt (-s) und direkt ausgewertet (-n 1)
read -n 1 -s EINGABE

# Überprüfen ob auch wirklich nur eine Zahl eingegeben wurde
if [[ -n ${EINGABE//[0-9]/} ]]; then
    echo -e "[${RED}!${RESET}] Bitte eine der angezeigten Optionen auswählen"
    exit 1
fi

# Wenn der Value-Wert eines ausgewählten Array-Elementes den Substring "ansible_" enthält 
# wird die dort entsprechende Ansible-Version aktiviert
if [[ "${arr[${EINGABE}]}" == "ansible_dev" ]] ;
then
  /bin/bash -c 'echo "Zum beenden \"exit\" eingeben"';/bin/bash --rcfile ${DEVINSTALLDIR}/hacking/env-setup
elif [[ "${arr[${EINGABE}]}" == *"ansible_"* ]] ;
then
  echo -e "${GREEN}${arr[${EINGABE}]}${RESET} wird aktiviert..."
  # die ausgewählte Ansible-Version wird in einer sub-shell gestartet, darum das /bin/bash am Ende des Befehls
  /bin/bash -c 'echo "Zum beenden \"exit\" eingeben"';/bin/bash --rcfile ${DEFAULTPATH}/${arr[${EINGABE}]}/bin/activate
# Wenn die Abruch-Option ausgewählt wird, wird mit exit 0 beendet
elif [[ "${arr[${EINGABE}]}" == "ende"  ]] ;
then
  echo -e "[${GREEN}*${RESET}] ENDE (Exit Code 0)"
  exit 0
elif [[ "${arr[${EINGABE}]}" == "install_dev" ]] ;
then
  if [ -d "${DEVINSTALLDIR}" ] ; then
    rm -rf ${DEVINSTALLDIR} 
  fi
  git clone https://github.com/ansible/ansible.git ${DEVINSTALLDIR}
  source ${DEVINSTALLDIR}/hacking/env-setup
  pip install --user -r ${DEVINSTALLDIR}/requirements.txt;/bin/bash
  exit 0
# Wenn eine neue Ansible-Version eingerichtet werden soll, wird zuerst gefragt welche Version es sein soll
elif [[ "${arr[${EINGABE}]}" == "neue_version" ]] ;
then
  echo "Welche Ansible Version soll eingerichtet werden?"
  read VERSION
  # Wenn keine Version angegeben wird, wird der oben eingerichetete Default-Wert verwendet
  if [[ "$VERSION" == "" ]] ; 
  then
    VERSION=$DEFAULTANSIBLEVERSION
  fi
  INVENTORYDIR=$DEFAULTPATH
  # Ab hier beginnt das "reguläre" Installationsscript, welches die Ansible-Version in einem Virtualdev installiert
  while getopts ":v:h" opt; do
    case ${opt} in
      v)
        VERSION=${OPTARG}
        ;;
      h)
        usage
        exit 0
        ;;
      \?)
        echo "[${RED}!${RESET}] Invalid option: -${OPTARG}" >&2
        usage
        exit ${STATUS_UNKNOWN}
        ;;
      :)
        echo "[${RED}!${RESET}] Option -${OPTARG} requires an argument." >&2
        exit ${STATUS_UNKNOWN}
        ;;
    esac
  done
  shift $((OPTIND-1))

  local_inventory_absolute_dir=$(readlink -fn ${INVENTORYDIR})
  local_inventory=${local_inventory_absolute_dir}/inventory_local_${VERSION}

  echo -e "[${GREEN}*${RESET}] pip install --user --upgrade pip "
  pip install --user --upgrade pip 1>/dev/null || exit 1
  
  echo -e "[${GREEN}*${RESET}] pip install --user virtualenv "
  pip install --user virtualenv 1>/dev/null|| exit 1
  
  echo -e "[${GREEN}*${RESET}] virtualenv ansible_${VERSION} "
  virtualenv ${DEFAULTPATH}/ansible_${VERSION} 1>/dev/null || exit 1
  
  echo -e "[${GREEN}*${RESET}] source ansible_${VERSION}/bin/activate "
  source ${DEFAULTPATH}/ansible_${VERSION}/bin/activate 1>/dev/null || exit 1
  
  echo -e "[${GREEN}*${RESET}] pip install --upgrade setuptools "
  pip install --upgrade setuptools 1>/dev/null || exit 1
  
  echo -e "[${GREEN}*${RESET}] pip install ansible==${VERSION} "
  pip install ansible==${VERSION} 1>/dev/null || exit 1
  
  echo -e "[${GREEN}*${RESET}] pip install extra modules "
  pip install requests bigsuds f5-sdk f5-icontrol-rest netaddr deepdiff 1>/dev/null || exit 1
  
  echo -e "[${GREEN}*${RESET}] modules for ansible-lint"
  pip install cryptography ipaddress enum34 ansible-lint 1>/dev/null || exit 1
  
  echo -e "${GREEN}### Ansible Aktivieren ###${RESET}"
  echo "zum Aktivieren jetzt:"
  echo "source ${DEFAULTPATH}/ansible_${VERSION}/bin/activate"
  echo ""
  echo "zum Deaktivieren danach:"
  echo -e "${RED}deactivate${RESET}"
  echo ""
  echo "wenn das Python vom venv fuer localhost benoetigt wird:"
  echo "'-i ${local_inventory}'"
  echo "als zusaetzliches Inventory uebergeben"
else
  echo -e "[${RED}!${RESET}] Option nicht gefunden"
  exit 1
fi
