#!/bin/bash
set -Eeo pipefail

main() {
  # check root
  [[ $(id -u) -ne 0 ]] && echo "You should run scirpt with root permission" && return 1
  # if networkmanager and dnsmasq exists, apply dns fix, and then refresh dns
  local dnsfix='false'
  local dnsconf='/etc/NetworkManager/dnsmasq.d/clash_tuner_dnsfix_dns.conf'
  systemctl is-active --quiet NetworkManager && ps -ef | grep -E 'dnsmasq.*Net' | grep -v grep > /dev/null && [[ ! -f $dnsconf ]] && dnsfix='true' || echo "DNS will not be flushed"
  [[ $dnsfix = true ]] && echo 'server=223.5.5.5' > $dnsconf
  [[ $dnsfix = true ]] && kill -HUP $(ps -ef | grep -E 'dnsmasq.*Net' | grep -v grep | awk '{print $2}') 
  # main
  local user=${1:-limc} conf=${2:-/} perm=${3:-false} backend=${4:-clash-meta}
  local pidpath="/run/${backend}.pid"
  conf="$(eval echo "~$user")/.config/clash/$conf"
  # remove duplicated tailing slashes
  conf=${conf%//*}
  [[ -s $pidpath ]] && ps "$(cat $pidpath)" | grep 'clash' > /dev/null && (kill $(cat $pidpath) && rm $pidpath || (echo "Can not kill services or remove pid file, you should rm or kill it manually" && return 1))
  local sername
  [[ $perm = true ]] && sername="${backend}-tuner-perm@${user}" || sername="${backend}-tuner@${user}"
  echo "conf=$conf" > /usr/lib/clash-tuner/env 
  # runuser -u "$user" -- systemctl --user start "$sername"
  # runuser -u "$user" -- systemctl --user show -p MainPID --value "$sername" > "$pidpath"
  systemctl start "$sername"
  echo $(systemctl show -p MainPID --value "$sername") > "$pidpath"
  [[ $dnsfix = true ]] && rm $dnsconf && kill -HUP $(ps -ef | grep -E 'dnsmasq.*Net' | grep -v grep | awk '{print $2}') && echo "DNS cache have been flushed"
  return 0
}

# 1=user 2=conf 3=perm 4=backend
main "$@"
