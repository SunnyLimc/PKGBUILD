#!/bin/bash
set -Eeo pipefail

main() {
  # check root
  [[ $(id -u) -ne 0 ]] && echo "You should run scirpt with root permission" && return 1
  # if networkmanager and dnsmasq exists, apply dns fix, and then refresh dns
  local dnsfix='false'
  local dnsconf='/etc/NetworkManager/dnsmasq.d/clash_tuner_dnsfix_dns.conf'
  systemctl is-active --quiet NetworkManager && [[ ! -f $dnsconf ]] && dnsfix='true'
  [[ $dnsfix = true ]] && echo 'server=223.5.5.5' > $dnsconf
  [[ $dnsfix = true ]] && kill -HUP $(ps -ef | grep -E 'dnsmasq.*Net' | grep -v grep | awk '{print $2}') 
  # main
  local user=${1:-limc} conf=${2:-/} perm=${3:-false} backend=${4:-clash-meta}
  local pidpath="/run/${backend}.pid"
  conf="$(eval echo "~$user")/.config/clash/$conf"
  # remove duplicated tailing slashes
  conf=${conf%//*}
  [[ -s $pidpath ]] && ps -p "$(cat $pidpath)" > /dev/null && (kill $(cat $pidpath) && rm $pidpath || (echo "Can not kill services or remove pid file, you should rm or kill it manually" && return 1))
  local sername="${backend}-tuner@${user}"
  echo $sername
  echo "conf=$conf" > /usr/lib/clash-tuner/env 
  if [[ $perm = true ]]; then
    systemctl start "$sername"
    echo $(systemctl show -p MainPID --value "$sername") > "$pidpath"
  else
    runuser -u "$user" -- systemctl --user start "$sername"
    runuser -u "$user" -- systemctl --user show -p MainPID --value "$sername" > "$pidpath"
  fi
  [[ $dnsfix = true ]] && rm $dnsconf && kill -HUP $(ps -ef | grep -E 'dnsmasq.*Net' | grep -v grep | awk '{print $2}') && echo "DNS cache have been flushed"
}

# 1=user 2=conf 3=perm 4=backend
main "$@"
