#!/bin/bash
set -Eeo pipefail
path="/home/limc/.config/clash"
trap '_ERROR' ERR
trap 'rm -r -- $tmp' EXIT
tmp="$(mktemp -d)"

#! ALL THE PARAMETERS BELOW ARE LOAD FROM `$HOME/.config/clash/clash-updater.env`. YOU SHOULD NOT EDIT THIS FILE MANULLY

# Your Clash configs profiles
# please use `%` as the separator for dirived-configs (`%` will be replace to `_` as the folder put into $path finally)
# e.g. `iqzone` will be saved to `$path/iqzone/config.yaml`
# AND `iqzone%tun` will be finally saved to `$path/iqzone_tun/config.yaml`
# derived-configs: different parameters added to the SAME subscription url
# e.g. iqzone and iqzone%tun will both using the iqzone_url
profiles=(iqzone iqzone%tun iqzone_meta iqzone_meta%tun)
# append `_url` to your profiles variable indicate the base url of the subscription
iqzone_url="https://YOUR-BACKEND/"
iqzone_meta_url="https://YOUR-BACKEND/"
# the default config will be saved to the `$path/config.yaml``
default=iqzone
# paramaters needed for adding to the profiles using the same url
# e.g. append `&dns=true` to `${iqzone_url}`
# leaft it empty or not to explicitly configured to disable the feature for the profile
# e.g. `iqzone%tun` and `iqzone` is sharing `iqzone_paras`, leave `iqzone_paras` empty to disable this feature
#! PLEASE AVIOD NAMING AMBIGIOUS MANUALLY
iqzone_paras=(dns api lan tun)
iqzone_meta_paras=(dns api lan tun)
# default extraval for profiles using the same url
iqzone_dns_deft=true
iqzone_api_deft=true
iqzone_lan_deft=true
iqzone_tun_deft=false
iqzone_meta_dns_deft=true
iqzone_meta_api_deft=true
iqzone_meta_lan_deft=true
iqzone_meta_tun_deft=false
# derived-configs
# e.g. `iqzone_tun%tun` is the derived-config profile `iqzone%tun`, and the `tun` parameter defined by `iqzone_paras` can set by variable `iqzone_tun_tun` (substitute `iqzone%tun` to `iqzone_tun`, and append `_tun`, in this case: true) to replace the default `iqzone_tun_deft` (in this case: false)
iqzone_tun_tun=true
iqzone_meta_tun_tun=true

##### END #####

_ERROR() {
  echo "[ERR] Detected"
  [[ -f ${tmp}/wconf ]] && echo "[LOG ECHO] last 15 lines of downloaded config" && cat ${tmp}/wconf | tail -n15
  echo ERROR: Script aborted
}

# load conf or exit
confpath=$HOME/.config/clash/clash-updater.env
echo "[CONF] Loading config from $confpath"
[[ -f $confpath ]] && source $confpath || (echo "[ERR]"echo "[INFO] For conf syntax you can reveal it from this script. (run: \`less $(which clash-updater)\`)" && exit 1 )

if [[ $1 != '--bypass-dat' ]]; then
  echo Downloading: Counrties-based GeoIP.dat
  if wget -O "$tmp"/dat "https://cdn.jsdelivr.net/gh/Loyalsoldier/geoip@release/geoip.dat" -q --show-progress; then
    cp "$tmp"/dat "$path"/GeoIP.dat
    echo Downloaded: "$path"/GeoIP.dat
  else
    exit 1
  fi
  echo Downloading: Counrties-based Country.mmdb
  if wget -O "$tmp"/dat "https://cdn.jsdelivr.net/gh/Dreamacro/maxmind-geoip@release/Country.mmdb" -q --show-progress; then
    cp "$tmp"/dat "$path"/Country.mmdb
    echo Downloaded: "$path"/Country.mmdb
  else
    exit 1
  fi
fi

for i in "${profiles[@]}"; do
  url="${i/\%*/}_url"
  exp_url="${!url}"
  dns=${dns_deft} api=${api_deft} lan=${lan_deft} tun=${tun_deft}
  parav="${i/\%*/}_paras[@]"
  for j in "${!parav}"; do
    exp="${i//%/_}"_"$j"
    expd="${i/\%*/}_${j}_deft"
    [[ -z "${!exp}" ]] && declare val="${!expd}" || declare val="${!exp}"
    exp_url="${exp_url}&${j}=${val}"
  done
  echo Downloading: ${i//%/_} FROM ${exp_url}
  if mkdir -p "$path"/${i//%/_} && wget -O "${tmp}/wconf" "$exp_url" -q --show-progress && [[ $(wc -l < ${tmp}/wconf) -ge 5 ]]; then
     cp ${tmp}/wconf "$path"/"${i//%/_}"/config.yaml
     [[ ${i//%/_} = $default ]] && cp "$path"/"${i//%/_}"/config.yaml "$path"/config.yaml
     if [[ $1 != '--bypass-dat' ]]; then
       cp "$path"/GeoIP.dat "$path"/${i//%/_}/
       cp "$path"/Country.mmdb "$path"/${i//%/_}/
     fi
     echo "Downloaded: "$path"/"${i//%/_}"/config.yaml"
  else
    echo "[ERROR] Check integrity for file manually. (lines of content >= 5)"
    exit 1
  fi
done

[[ $1 = '--bypass-dat' ]] && echo "[WARN] Script successfully finished. (and NO IP-DB files updated, without any of those, Clash may not working)" || echo "[OK] Script successfully finished."

exit 0
