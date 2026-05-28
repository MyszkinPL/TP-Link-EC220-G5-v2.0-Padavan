#!/usr/bin/env bash
set -euo pipefail

PADAVAN_DIR="${PADAVAN_DIR:-padavan-ng}"
TRUNK_DIR="$PADAVAN_DIR/trunk"
NFQWS_DIR="$TRUNK_DIR/user/nfqws"
SERVICES_C="$TRUNK_DIR/user/rc/services.c"

if [[ ! -d "$NFQWS_DIR" ]]; then
  echo "nfqws package directory not found: $NFQWS_DIR" >&2
  exit 1
fi

if [[ ! -f "$SERVICES_C" ]]; then
  echo "services.c not found: $SERVICES_C" >&2
  exit 1
fi

grep -q 'check_if_file_exist("/usr/bin/nfqws")' "$SERVICES_C" || {
  echo "expected nfqws service check not found in $SERVICES_C" >&2
  exit 1
}

grep -q 'pids("zapret")' "$SERVICES_C" || {
  echo "expected zapret pid check not found in $SERVICES_C" >&2
  exit 1
}

sed -i 's|check_if_file_exist("/usr/bin/nfqws")|check_if_file_exist("/usr/bin/nfqws2")|' "$SERVICES_C"
sed -i 's|pids("zapret")|pids("nfqws2")|' "$SERVICES_C"

MAIN_CSS="$TRUNK_DIR/user/www/n56u_ribbon_fixed/bootstrap/css/main.css"
if [[ ! -f "$MAIN_CSS" ]]; then
  echo "main.css not found: $MAIN_CSS" >&2
  exit 1
fi

if ! grep -q 'codex-ui-polish' "$MAIN_CSS"; then
  cat >> "$MAIN_CSS" <<'CSS_EOF'

/* codex-ui-polish: compact admin UI refresh for small-flash Padavan builds. */
body {
    background: #e8eef5;
    color: #182334;
    font-family: "Segoe UI", Tahoma, sans-serif;
}

body.body_iframe {
    background: #f7f9fc;
}

.wrapper {
    width: 1040px;
}

#logo {
    margin-top: 28px;
    opacity: 0.9;
}

#footer {
    color: #526172;
    text-shadow: none;
}

.well,
.box {
    background: #ffffff;
    border: 1px solid #d7e0ea;
    border-radius: 6px;
    box-shadow: 0 10px 24px rgba(24, 35, 52, 0.08);
}

.side_nav .well,
.sidebar-nav {
    overflow: hidden;
}

.bar_nav ul a,
.side_nav ul a,
li div.accordion a {
    background: #ffffff;
    color: #235f89;
    border-top: 0;
    border-bottom: 1px solid #e4ebf2;
    text-shadow: none;
    font: 600 12px/31px "Segoe UI", Tahoma, sans-serif;
}

li div.accordion a {
    background: #f8fbfe;
    color: #2c6c96;
    padding-left: 28px;
}

.bar_nav ul li:hover > a,
.side_nav ul li:hover > a,
.side_nav ul li.active > a,
.clearfix li.active > a {
    background: #2b6f9f;
    color: #ffffff;
    border-color: #2b6f9f;
    text-shadow: none !important;
}

.box.grad_colour_dark_blue h2.box_head {
    background: #245f8c;
    border-color: #245f8c;
    color: #ffffff;
    text-shadow: none;
}

.table {
    background: #ffffff;
}

.table th,
.table td {
    border-top: 1px solid #e2e9f1;
    padding: 8px 10px;
}

.table th {
    color: #182334;
    font-weight: 600;
}

.badge,
.label {
    border-radius: 3px;
    text-shadow: none;
}

.btn {
    border-radius: 4px;
    box-shadow: none;
}

input,
select,
textarea {
    border-color: #cbd6e2;
}

textarea {
    background: #fbfdff;
}
CSS_EOF
fi

cat > "$NFQWS_DIR/Makefile" <<'MAKEFILE_EOF'
ZAPRET2_VER ?= $(if $(ZAPRET2_VERSION),$(ZAPRET2_VERSION),0.9.5.2)
SRC_NAME = zapret2-v$(ZAPRET2_VER)
SRC_ARCHIVE = $(SRC_NAME)-openwrt-embedded.tar.gz
SRC_URL = https://github.com/bol-van/zapret2/releases/download/v$(ZAPRET2_VER)/$(SRC_ARCHIVE)
ZAPRET2_ARCH ?= linux-mipsel

all: download_test extract_test

download_test:
	( if [ ! -f $(SRC_ARCHIVE) ]; then \
		wget -t5 -T20 --no-check-certificate -O $(SRC_ARCHIVE) $(SRC_URL) || { rm -f $(SRC_ARCHIVE); exit 1; }; \
	fi )

extract_test: download_test
	( if [ ! -d $(SRC_NAME) ]; then \
		tar zxf $(SRC_ARCHIVE); \
	fi; \
	test -x $(SRC_NAME)/binaries/$(ZAPRET2_ARCH)/nfqws2; \
	test -f $(SRC_NAME)/lua/zapret-lib.lua.gz; \
	test -f $(SRC_NAME)/lua/zapret-antidpi.lua.gz; \
	test -f $(SRC_NAME)/lua/zapret-auto.lua.gz; \
	)

clean:
	true

romfs: extract_test
	$(ROMFSINST) -p +x $(SRC_NAME)/binaries/$(ZAPRET2_ARCH)/nfqws2 /usr/bin/nfqws2
	$(ROMFSINST) -p +x zapret2-padavan.sh /usr/bin/zapret.sh
	$(ROMFSINST) -d $(SRC_NAME)/lua /usr/share/zapret2/lua
	$(ROMFSINST) -d zapret2-defaults /usr/share/zapret2/defaults
MAKEFILE_EOF

cat > "$NFQWS_DIR/zapret2-padavan.sh" <<'SCRIPT_EOF'
#!/bin/sh

NFQWS_BIN="/usr/bin/nfqws2"
ETC_DIR="/etc"

[ -d "/etc_ro" -a -d "/etc/storage" ] && ETC_DIR="/etc/storage"

CONF_DIR="${ETC_DIR}/zapret"
CONF_DIR_EXAMPLE="/usr/share/zapret2/defaults"
CONF_FILE="$CONF_DIR/config"
STRATEGY_FILE="$CONF_DIR/strategy"
PID_FILE="/var/run/zapret2.pid"
POST_SCRIPT="$CONF_DIR/post_script.sh"
LUA_DIR="/usr/share/zapret2/lua"

HOSTLIST_DOMAINS="https://github.com/1andrevich/Re-filter-lists/releases/latest/download/domains_all.lst"
HOSTLIST_MARKER="<HOSTLIST>"
HOSTLIST_NOAUTO_MARKER="<HOSTLIST_NOAUTO>"
HOSTLIST_NOAUTO="
  --hostlist=${CONF_DIR}/user.list
  --hostlist=${CONF_DIR}/auto.list
  --hostlist-exclude=${CONF_DIR}/exclude.list
  --hostlist=/tmp/filter.list
"
HOSTLIST="
  --hostlist=${CONF_DIR}/user.list
  --hostlist-exclude=${CONF_DIR}/exclude.list
  --hostlist-auto=${CONF_DIR}/auto.list
  --hostlist=/tmp/filter.list
"

DESYNC_MARK="0x40000000"
FILTER_MARK="0x10000000"

ISP_INTERFACE=
NFQUEUE_NUM=200
LOG_LEVEL=0
RUN_AS_USER=
CLIENTS_ALLOWED=

log()
{
    [ -n "$*" ] || return
    echo "$@"
    local pid
    [ -f "$PID_FILE" ] && pid="[$(cat "$PID_FILE" 2>/dev/null)]"
    logger -t "zapret2$pid" "$@"
}

trim()
{
    awk '{gsub(/^ +| +$/,"")}1'
}

error()
{
    log "$@"
    exit 1
}

_get_if_default()
{
    ip -$1 route show default | grep via | sed -r 's/^.*default.*via.* dev ([^ ]+).*$/\1/' | head -n1
}

isp_is_present()
{
    [ "$(echo "$ISP_IF" | tr -d ' ,\n')" ]
}

_get_ports()
{
    grep -v "^#" "$STRATEGY_FILE" | tr -d '"' | grep -o "[-][-]filter-$1=[0-9][0-9,-]*" \
        | cut -d '=' -f2 | tr -s ',' '\n' | sort -u \
        | sed -ne 'H;${x;s/\n/,/g;s/-/:/g;s/^,//;p;}'
}

get_port_list()
{
    local port_limit=7
    echo "$1" | tr ',' '\n' | xargs -n$port_limit | tr ' ' ','
}

_mangle_rules()
{
    local i iface filter ports

    if [ "$CLIENTS_ALLOWED" -a ! "$1" ]; then
        filter="-m mark --mark $FILTER_MARK/$FILTER_MARK"
        echo "-A OUTPUT -j MARK --or-mark $FILTER_MARK"
        for i in $CLIENTS_ALLOWED; do
            echo "-A PREROUTING -s $i -j MARK --or-mark $FILTER_MARK"
        done
    fi

    local rule_nfqueue="-j NFQUEUE --queue-num $NFQUEUE_NUM --queue-bypass"
    local rule_output_end="$filter -m mark ! --mark $DESYNC_MARK/$DESYNC_MARK -m connbytes --connbytes 1:12 --connbytes-mode packets --connbytes-dir original $rule_nfqueue"

    for iface in $ISP_IF; do
        for ports in $(get_port_list "$TCP_PORTS"); do
            echo "-A PREROUTING -i $iface -p tcp -m multiport --sports $ports -m connbytes --connbytes 1:4 --connbytes-mode packets --connbytes-dir reply $rule_nfqueue"
            echo "-A POSTROUTING -o $iface -p tcp -m multiport --dports $ports $rule_output_end"
        done
        for ports in $(get_port_list "$UDP_PORTS"); do
            echo "-A POSTROUTING -o $iface -p udp -m multiport --dports $ports $rule_output_end"
        done
    done
}

is_running()
{
    [ -z "$(pidof "$(basename "$NFQWS_BIN")" 2>/dev/null)" ] && return 1
    [ -f "$PID_FILE" ]
}

status_service()
{
    if is_running; then
        echo "service nfqws2 is running"
        exit 0
    else
        echo "service nfqws2 is stopped"
        exit 1
    fi
}

kernel_modules()
{
    for i in nfnetlink_queue xt_connbytes xt_NFQUEUE ip6table_mangle; do
        modprobe -q $i >/dev/null 2>&1
    done
}

replace_str()
{
    local a=$(echo "$1" | sed 's/\//\\\//g')
    local b=$(echo "$2" | tr -s '\n' ' ' | sed 's/\//\\\//g')
    shift; shift
    echo "$@" | tr -s '\n' ' ' | sed "s/$a/$b/g; s/[ \t]\{1,\}/ /g"
}

startup_args()
{
    [ -f /tmp/filter.list ] || touch /tmp/filter.list

    local args="--qnum=$NFQUEUE_NUM --fwmark=$DESYNC_MARK"
    [ "$RUN_AS_USER" ] && args="--user=$RUN_AS_USER $args"
    [ "$LOG_LEVEL" = "1" ] && args="--debug=syslog $args"

    args="$args --lua-init=@$LUA_DIR/zapret-lib.lua.gz"
    args="$args --lua-init=@$LUA_DIR/zapret-antidpi.lua.gz"
    args="$args --lua-init=@$LUA_DIR/zapret-auto.lua.gz"
    args="$args --lua-init=fake_default_tls=tls_mod(fake_default_tls,'rnd,rndsni')"

    NFQWS_ARGS="$(grep -v '^#' "$STRATEGY_FILE" | tr -d '"')"
    NFQWS_ARGS=$(replace_str "$HOSTLIST_MARKER" "$HOSTLIST" "$NFQWS_ARGS")
    NFQWS_ARGS=$(replace_str "$HOSTLIST_NOAUTO_MARKER" "$HOSTLIST_NOAUTO" "$NFQWS_ARGS")
    echo "$args $NFQWS_ARGS"
}

iptables_stop()
{
    local i
    for i in "" "6"; do
        command -v ip${i}tables-save >/dev/null 2>&1 || continue
        [ "$i" = "6" ] && [ ! -d /proc/sys/net/ipv6 ] && continue
        ip${i}tables-restore -n <<EOF
*mangle
$(ip${i}tables-save -t mangle 2>/dev/null | sed -n "/\(queue-num $NFQUEUE_NUM --queue\|mark $DESYNC_MARK\/$DESYNC_MARK\|mark $FILTER_MARK\/$FILTER_MARK\)/{s/^-A/-D/p}")
COMMIT
EOF
    done
}

iptables_start()
{
    UDP_PORTS=$(echo $UDP_PORTS | tr -s "-" ":")
    TCP_PORTS=$(echo $TCP_PORTS | tr -s "-" ":")

    local i
    for i in "" "6"; do
        command -v ip${i}tables-restore >/dev/null 2>&1 || continue
        [ "$i" = "6" ] && [ ! -d /proc/sys/net/ipv6 ] && continue
        ip${i}tables-restore -n <<EOF
*mangle
$(_mangle_rules $i)
COMMIT
EOF
    done
}

firewall_stop()
{
    iptables_stop
}

firewall_start()
{
    firewall_stop

    if isp_is_present; then
        iptables_start
        log "firewall rules updated on interface(s): $(echo "$ISP_IF" | tr -s '\n' ' ' | trim)"
    else
        log "interfaces not defined, firewall rules not set"
    fi
}

system_config()
{
    sysctl -w net.netfilter.nf_conntrack_checksum=0 >/dev/null 2>&1
    sysctl -w net.netfilter.nf_conntrack_tcp_be_liberal=1 >/dev/null 2>&1
}

set_strategy_file()
{
    [ "$1" ] || return

    local candidate="$1"
    case "$candidate" in
        [0-9]) candidate="strategy${candidate}" ;;
    esac

    [ -f "$candidate" ] && STRATEGY_FILE="$candidate" && return
    [ -f "${CONF_DIR}/$candidate" ] && STRATEGY_FILE="${CONF_DIR}/$candidate" && return
}

start_service()
{
    [ -s "$NFQWS_BIN" -a -x "$NFQWS_BIN" ] || error "$NFQWS_BIN: not found or invalid"
    if is_running; then
        echo "already running"
        return
    fi

    kernel_modules

    res=$($NFQWS_BIN --daemon --pidfile=$PID_FILE $(startup_args) 2>&1)
    if [ ! "$?" = "0" ]; then
        log "failed to start: $(echo "$res" | grep 'github version')"
        echo "$res" | grep -Ei 'unrecognized|invalid|error' \
        | while read -r i; do
            log "$i"
        done
        exit 1
    fi

    log "started, $(echo "$res" | grep 'github version')"
    [ "$CLIENTS_ALLOWED" ] && log "allowed clients: $CLIENTS_ALLOWED"
    log "use strategy from $STRATEGY_FILE"
    echo "$res" | grep -Ei "loaded|profile" | while read -r i; do
        log "$i"
    done

    system_config
    firewall_start
}

stop_service()
{
    firewall_stop
    killall -q -s 15 "$(basename "$NFQWS_BIN")" && log "stopped"
    rm -f "$PID_FILE"
}

reload_service()
{
    is_running || return
    firewall_start
    kill -HUP "$(cat "$PID_FILE")"
}

download_list()
{
    local list="/tmp/filter.list"

    if [ -x /usr/bin/curl ]; then
        curl -sSL --connect-timeout 5 "$HOSTLIST_DOMAINS" -o "$list" || error "unable to download $HOSTLIST_DOMAINS"
    else
        wget -q -T 10 "$HOSTLIST_DOMAINS" -O "$list" || error "unable to download $HOSTLIST_DOMAINS"
    fi

    [ -s "$list" ] && log "downloaded successfully: $HOSTLIST_DOMAINS"
}

if id -u >/dev/null 2>&1; then
    [ "$(id -u)" != "0" ] && echo "root user is required to start" && exit 1
fi

[ -f "$CONF_DIR" ] && rm -f "$CONF_DIR"
[ -d "$CONF_DIR" ] || mkdir -p "$CONF_DIR" || exit 1
[ -d "$CONF_DIR_EXAMPLE" ] && false | cp -i "${CONF_DIR_EXAMPLE}"/* "$CONF_DIR" >/dev/null 2>&1

[ -s "$CONF_FILE" ] && . "$CONF_FILE"

for i in user.list exclude.list auto.list strategy strategy0 strategy1 strategy2 strategy3 strategy4 strategy5 strategy6 strategy7 strategy8 strategy9 config; do
    [ -f "${CONF_DIR}/$i" ] || touch "${CONF_DIR}/$i" || exit 1
done

if [ -x "/usr/sbin/nvram" ]; then
    t="$(nvram get zapret_iface)" && [ -n "$t" ] && ISP_INTERFACE="$t"
    t="$(nvram get zapret_log)" && [ -n "$t" ] && LOG_LEVEL="$t"
    t="$(nvram get zapret_strategy)" && [ -n "$t" ] && set_strategy_file "$t"
    t="$(nvram get zapret_clients_allowed)" && [ -n "$t" ] && CLIENTS_ALLOWED="$t"
    unset t
fi

CLIENTS_ALLOWED=$(echo $CLIENTS_ALLOWED | tr -s ',' ' ' | trim)

unset ISP_IF
if [ "$ISP_INTERFACE" ]; then
    ISP_IF=$(echo "$ISP_INTERFACE" | tr -s ',' ' ' | trim | tr -s ' ' '\n' | sort -u)
else
    ISP_IF4=$(_get_if_default 4)
    ISP_IF6=$(_get_if_default 6)
    ISP_IF=$(printf "%s\n%s" "${ISP_IF4}" "${ISP_IF6}" | sort -u)
fi

set_strategy_file "$2"
[ -s "$STRATEGY_FILE" ] || error "strategy file is empty: $STRATEGY_FILE"
TCP_PORTS=$(_get_ports tcp)
UDP_PORTS=$(_get_ports udp)

case "$1" in
    start)
        start_service
    ;;
    stop)
        stop_service
    ;;
    status)
        status_service
    ;;
    restart)
        stop_service
        start_service
    ;;
    firewall-start)
        firewall_start
    ;;
    firewall-stop)
        firewall_stop
    ;;
    reload)
        reload_service
    ;;
    download-list)
        download_list
    ;;
    *)
        echo "Usage: $0 {start [strategy_file]|stop|restart [strategy_file]|download-list|status|reload}"
    ;;
esac

[ -s "$POST_SCRIPT" -a -x "$POST_SCRIPT" ] && . "$POST_SCRIPT"
SCRIPT_EOF

mkdir -p "$NFQWS_DIR/zapret2-defaults"

cat > "$NFQWS_DIR/zapret2-defaults/config" <<'CONFIG_EOF'
# comma separated list of WAN interfaces. Empty means default IPv4/IPv6 routes.
ISP_INTERFACE=

# comma separated list of client IPv4 addresses. Empty disables client restrictions.
#CLIENTS_ALLOWED="192.168.1.0/24"

# Optional custom strategy file path.
#STRATEGY_FILE="/etc/storage/zapret/strategy"

# 0 - quiet, 1 - syslog debug.
LOG_LEVEL=0

# Leave empty for best static-binary compatibility on embedded firmware.
RUN_AS_USER=
CONFIG_EOF

touch "$NFQWS_DIR/zapret2-defaults/user.list"
touch "$NFQWS_DIR/zapret2-defaults/exclude.list"
touch "$NFQWS_DIR/zapret2-defaults/auto.list"

cat > "$NFQWS_DIR/zapret2-defaults/strategy" <<'STRATEGY_EOF'
# zapret2/nfqws2 default Padavan strategy. Edit in /etc/storage/zapret after first boot.

--filter-tcp=80 --filter-l7=http
--out-range=-d10
--payload=http_req
--lua-desync=fake:blob=fake_default_http:tcp_md5
--lua-desync=fakeddisorder:pos=sld+1:seqovl=1:seqovl_pattern=0x60cc104332bd1c7e:tcp_md5
<HOSTLIST>

--new --filter-tcp=443 --filter-l7=tls
--out-range=-d10
--payload=tls_client_hello
--lua-desync=fake:blob=fake_default_tls:tcp_seq=-10000
--lua-desync=fakedsplit:pos=method+2:pattern=0x7dfd45599fdbbb3f:seqovl=1:seqovl_pattern=0xd34ee39ef66cc60f
--lua-desync=multisplit:pos=midsld,5:seqovl=1:seqovl_pattern=0xd34ee39ef66cc60f
<HOSTLIST>

--new --filter-udp=443 --filter-l7=quic
--payload=quic_initial
--lua-desync=fake:blob=fake_default_quic:repeats=6
<HOSTLIST_NOAUTO>

--new --filter-udp=50000-50099 --filter-l7=discord,stun
--payload=discord_ip_discovery,stun
--lua-desync=fake:blob=0x00000000000000000000000000000000:repeats=2

--new --filter-udp=1400 --filter-l7=stun
--payload=stun
--lua-desync=fake:blob=0x00000000000000000000000000000000:repeats=2
STRATEGY_EOF
