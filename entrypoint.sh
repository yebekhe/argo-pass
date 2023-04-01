#!/usr/bin/env bash

# Define UUID and masquerade path, please modify it yourself. (Note: The masquerading path starts with / symbol, in order to avoid unnecessary trouble, please do not use special symbols.)
UUID=${UUID:-'de04add9-5c68-8bab-950c-08cd5320df18'}
VMESS_WSPATH=${VMESS_WSPATH:-'/vmess'}
VLESS_WSPATH=${VLESS_WSPATH:-'/vless'}
TROJAN_WSPATH=${TROJAN_WSPATH:-'/trojan'}
SS_WSPATH=${SS_WSPATH:-'/shadowsocks'}
sed -i "s#UUID#$UUID#g;s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g;s#TROJAN_WSPATH#${TROJAN_WSPATH}#g;s#SS_WSPATH#${SS_WSPATH}#g" config.json
sed -i "s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g;s#TROJAN_WSPATH#${TROJAN_WSPATH}#g;s#SS_WSPATH#${SS_WSPATH}#g" /etc/nginx/nginx.conf

# Set nginx masquerade station
rm -rf /usr/share/nginx/*
wget https://gitlab.com/Misaka-blog/xray-paas/-/raw/main/mikutap.zip -O /usr/share/nginx/mikutap.zip
unzip -o "/usr/share/nginx/mikutap.zip" -d /usr/share/nginx/html
rm -f /usr/share/nginx/mikutap.zip

# Fake xray executable file
RELEASE_RANDOMNESS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 6)
mv xray ${RELEASE_RANDOMNESS}
wget https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
wget https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat
cat config.json | base64 > config
rm -f config.json

# If there are three variables set for the Nezha probe, it will be installed. If not filled or incomplete, it will not be installed
[ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_PORT}" ] && [ -n "${NEZHA_KEY}" ] && wget https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh -O nezha.sh && chmod +x nezha.sh && ./nezha.sh install_agent ${NEZHA_SERVER} ${NEZHA_PORT} ${NEZHA_KEY}

# Enable Argo, and output node logs
cloudflared tunnel --url http://localhost:80 --no-autoupdate > argo.log 2>&1 &
sleep 5 && argo_url=$(cat argo.log | grep -oE "https://.*[a-z]+cloudflare.com" | sed "s#https://##")

vmlink=$(echo -e '\x76\x6d\x65\x73\x73')://$(echo -n "{\"v\":\"2\",\"ps\":\"Argo_xray_vmess\",\"add\":\"$argo_url\",\"port\":\"443\",\"id\":\"$UUID\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"$argo_url\",\"path\":\"$VMESS_WSPATH?ed=2048\",\"tls\":\"tls\"}" | base64 -w 0)
vllink=$(echo -e '\x76\x6c\x65\x73\x73')"://"$UUID"@"$argo_url":443?encryption=none&security=tls&type=ws&host="$argo_url"&path="$VLESS_WSPATH"?ed=2048#Argo_xray_vless"
trlink=$(echo -e '\x74\x72\x6f\x6a\x61\x6e')"://"$UUID"@"$argo_url":443?security=tls&type=ws&host="$argo_url"&path="$TROJAN_WSPATH"?ed2048#Argo_xray_trojan"

qrencode -o /usr/share/nginx/html/M$UUID.png $vmlink
qrencode -o /usr/share/nginx/html/L$UUID.png $vllink
qrencode -o /usr/share/nginx/html/T$UUID.png $trlink

cat > /usr/share/nginx/html/$UUID.html<<-EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8" />
    <title>Argo-xray-paas</title>
    <style type="text/css">
        body {
            font-family: Geneva, Arial, Helvetica, san-serif;
        }

        div {
            margin: 0 auto;
            text-align: left;
            white-space: pre-wrap;
            word-break: break-all;
            max-width: 80%;
            margin-bottom: 10px;
        }
    </style>
</head>
<body bgcolor="#FFFFFF" text="#000000">
    <div>
        <font color="#009900"><b>VMESS protocol link：</b></font>
    </div>
    <div>$vmlink</div>
    <div>
        <font color="#009900"><b>VMESS protocol QR code：</b></font>
    </div>
    <div><img src="/M$UUID.png"></div>
    <div>
        <font color="#009900"><b>VLESS protocol link：</b></font>
    </div>
    <div>$vllink</div>
    <div>
        <font color="#009900"><b>VLESS protocol QR code：</b></font>
    </div>
    <div><img src="/L$UUID.png"></div>
    <div>
        <font color="#009900"><b>TROJAN protocol link：</b></font>
    </div>
    <div>$trlink</div>
    <div>
        <font color="#009900"><b>TROJAN protocol QR code：</b></font>
    </div>
    <div><img src="/T$UUID.png"></div>
    <div>
        <font color="#009900"><b>SS protocol plain text：</b></font>
    </div>
    <div>server address：$argo_url</div>
    <div>port：443</div>
    <div>password：$UUID</div>
    <div>Encryption：chacha20-ietf-poly1305</div>
    <div>Transfer Protocol：ws</div>
    <div>host：$argo_url</div>
    <div>path：$SS_WSPATH?ed=2048</div>
    <div>TLS：turn on</div>
</body>
</html>
EOF

nginx
base64 -d config > config.json
./${RELEASE_RANDOMNESS} -config=config.json
