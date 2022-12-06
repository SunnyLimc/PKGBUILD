#!/bin/bash
set -Eeo pipefail

pidpath="/run/clash-tuner.pid"

# $1=dnsconf
_refresh_dns() {
  local provider=${1:-system}
  local confpath='/etc/NetworkManager/dnsmasq.d/zzz-clash_tuner_dnsfix_dns.conf'
  if !(systemctl is-active --quiet NetworkManager && ps -ef | grep -E 'dnsmasq.*Net' | grep -v grep > /dev/null); then
    echo "[DNS] You are not currently using Dnsmasq with Networkmanager, configuration skipped."
    return 0
  fi
  if [[ $provider = system ]]; then
    [[ -f $confpath ]] && rm $confpath && echo "[DNS] Dnsmasq config added by clash-tuner has been removed (rm: $confpath)"
  elif [[ $provider = dns ]]; then
    (echo 'server='; echo 'server=223.5.5.5') > $confpath && echo "[DNS] 233.5.5.5 will be used as Dnsmasq upstream server (edited: $confpath)"
  elif [[ $provider = clash ]]; then
    (echo 'server='; echo 'server=127.0.1.1') > $confpath && echo "[DNS] 127.0.1.1 will be used as Dnsmasq upstream server (edited: $confpath)"
  fi
  # dnspid=$(ps -ef | grep -E 'dnsmasq.*Net' | grep -v grep | awk '{print $2}') && kill -SIGHUP $dnspid && echo "[DNS] DNS cache have been flushed (reloaded pid: $dnspid)"
  killall -SIGHUP dnsmasq && echo "[DNS] DNS cache have been flushed (killall: dnsmasq)"
}

_stop() {
  [[ -s $pidpath ]] && ps "$(cat $pidpath)" 2> /dev/null | grep 'clash' >> /dev/null && (echo "[Kill] Try to stop the old clash process (kill: $(cat $pidpath))" && kill $(cat $pidpath) && rm $pidpath && echo "[Service] Removed cache PID. (rm: $pidpath)" || (echo "[ERR] Can not kill services or remove pid file, you should rm or kill it manually" && return 1))
  _refresh_dns 'system'
  echo [Kill] Process has been stopped
}

# 1=user 2=conf 3=perm 4=backend
_start() {
  # main
  local user=${1:-limc} conf=${2:-/} perm=${3:-false} backend=${4:-clash-meta}
  conf="$(eval echo "~$user")/.config/clash/$conf"
  # remove duplicated tailing slashes
  conf=${conf%//*}
  _stop || return 1
  sleep 1 
  # dnsfix
  ping -c1 -W2 cdn.jsdelivr.net > /dev/null || (echo "[WARN] Try to fix network error" && _refresh_dns 'dns' && sleep 1) 
  local sername
  [[ $perm = true ]] && sername="${backend}-tuner-perm@${user}" || sername="${backend}-tuner@${user}"
  mkdir -p /usr/lib/clash-tuner
  echo "conf=$conf" > /usr/lib/clash-tuner/env || return 1
  echo "[Conf] Clash working path has been set to: $conf (edited: /usr/lib/clash-tuner/env)"
  # runuser -u "$user" -- systemctl --user start "$sername"
  # runuser -u "$user" -- systemctl --user show -p MainPID --value "$sername" > "$pidpath"
  echo [Service] Starting service: $sername
  systemctl start "$sername"
  sleep 1 
  local servpid=$(systemctl show -p MainPID --value "$sername") && echo $servpid > "$pidpath" && echo "[Service] Service started with PID: $servpid (edited: $pidpath)"
  _refresh_dns 'clash'
  return 0
}

# check root
[[ $(id -u) -ne 0 ]] && echo "[ERR] You should run scirpt with root permission" && exit 1

([[ $1 != 'stop' ]] && _start "$@" || _stop "$@") && echo "[DONE] Script finished." || echo "[ERR] Previous clash process can not be stopped. Script aborted."
