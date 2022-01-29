#!/bin/bash
function blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
function green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
function red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
function yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}

function initenv() {
    export CF_Token=""
    export CF_Email=""
    ssl_port=443
    http_port=80
}

function check_os(){
green "系统支持检测"
sleep 3s
if [[ -f /etc/redhat-release ]]; then
    release="centos"
    systemPackage="yum"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
    systemPackage="apt-get"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
    systemPackage="apt-get"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
    systemPackage="yum"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
    systemPackage="apt-get"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
    systemPackage="apt-get"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
    systemPackage="yum"
fi
if [ "$release" == "centos" ]; then
    if  [ -n "$(grep ' 6\.' /etc/redhat-release)" ] ;then
    red "==============="
    red "当前系统不受支持"
    red "==============="
    exit
    fi
    if  [ -n "$(grep ' 5\.' /etc/redhat-release)" ] ;then
    red "==============="
    red "当前系统不受支持"
    red "==============="
    exit
    fi
    rpm -Uvh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm >/dev/null 2>&1
    green "开始安装nginx编译依赖"
    yum install -y libtool perl-core zlib-devel gcc pcre* >/dev/null 2>&1
elif [ "$release" == "ubuntu" ]; then
    if  [ -n "$(grep ' 14\.' /etc/os-release)" ] ;then
    red "==============="
    red "当前系统不受支持"
    red "==============="
    exit
    fi
    if  [ -n "$(grep ' 12\.' /etc/os-release)" ] ;then
    red "==============="
    red "当前系统不受支持"
    red "==============="
    exit
    fi
    ufw_status=`systemctl status ufw | grep "Active: active"`
    if [ -n "$ufw_status" ]; then
        ufw allow 80/tcp
        ufw allow 443/tcp
    fi
    apt-get update >/dev/null 2>&1
    green "开始安装nginx编译依赖"
    apt-get install -y build-essential libpcre3 libpcre3-dev zlib1g-dev liblua5.1-dev libluajit-5.1-dev libgeoip-dev google-perftools libgoogle-perftools-dev >/dev/null 2>&1
elif [ "$release" == "debian" ]; then
    apt-get update >/dev/null 2>&1
    green "开始安装nginx编译依赖"
    apt-get install -y build-essential libpcre3 libpcre3-dev zlib1g-dev liblua5.1-dev libluajit-5.1-dev libgeoip-dev google-perftools libgoogle-perftools-dev >/dev/null 2>&1
fi
}

function check_env(){
green "安装环境监测"
sleep 3s
if [ -f "/etc/selinux/config" ]; then
    CHECK=$(grep SELINUX= /etc/selinux/config | grep -v "#")
    if [ "$CHECK" != "SELINUX=disabled" ]; then
        green "检测到SELinux开启状态，添加开放80/443端口规则"
	yum install -y policycoreutils-python >/dev/null 2>&1
        semanage port -m -t http_port_t -p tcp $http_port
        semanage port -m -t http_port_t -p tcp $ssl_port
    fi
fi
firewall_status=`firewall-cmd --state`
if [ "$firewall_status" == "running" ]; then
    green "检测到firewalld开启状态，添加放行80/443端口规则"
    firewall-cmd --zone=public --add-port=$http_port/tcp --permanent
    firewall-cmd --zone=public --add-port=$ssl_port/tcp --permanent
    firewall-cmd --reload
fi
$systemPackage -y install net-tools socat >/dev/null 2>&1
Port80=`netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w ${http_port}`
Port443=`netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w ${ssl_port}`
if [ -n "$Port80" ]; then
    process80=`netstat -tlpn | awk -F '[: ]+' '$5=="${http_port}"{print $9}'`
    red "==========================================================="
    red "检测到${http_port}端口被占用，占用进程为：${process80}，本次安装结束"
    red "==========================================================="
    exit 1
fi
if [ -n "$Port443" ]; then
    process443=`netstat -tlpn | awk -F '[: ]+' '$5=="${ssl_port}"{print $9}'`
    red "============================================================="
    red "检测到${ssl_port}端口被占用，占用进程为：${process443}，本次安装结束"
    red "============================================================="
    exit 1
fi
}
function install_nginx(){
    #apt-get purge iptables-persistent
    wget https://www.openssl.org/source/old/1.1.1/openssl-1.1.1a.tar.gz >/dev/null 2>&1
    tar xzvf openssl-1.1.1a.tar.gz >/dev/null 2>&1
    mkdir /etc/nginx
    mkdir /etc/nginx/ssl
    mkdir /etc/nginx/conf.d
    wget https://nginx.org/download/nginx-1.15.8.tar.gz >/dev/null 2>&1
    tar xf nginx-1.15.8.tar.gz && rm nginx-1.15.8.tar.gz >/dev/null 2>&1
    cd nginx-1.15.8
    ./configure --prefix=/etc/nginx --with-openssl=../openssl-1.1.1a --with-openssl-opt='enable-tls1_3' --with-http_v2_module --with-http_ssl_module --with-http_gzip_static_module --with-http_stub_status_module --with-http_sub_module --with-stream --with-stream_ssl_module  >/dev/null 2>&1
    green "开始编译安装nginx，编译等待时间可能较长，请耐心等待，通常需要几到十几分钟"
    sleep 3s
    make >/dev/null 2>&1
    make install >/dev/null 2>&1
    
cat > /etc/nginx/conf/nginx.conf <<-EOF
user  root;
worker_processes  1;
error_log  /etc/nginx/logs/error.log warn;
pid        /etc/nginx/logs/nginx.pid;
events {
    worker_connections  1024;
}
http {
    include       /etc/nginx/conf/mime.types;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
    access_log  /etc/nginx/logs/access.log  main;
    sendfile        on;
    #tcp_nopush     on;
    keepalive_timeout  120;
    client_max_body_size 20m;
    #gzip  on;
    include /etc/nginx/conf.d/*.conf;
}
EOF
    curl https://get.acme.sh | sh
    ~/.acme.sh/acme.sh --set-default-ca --server zerossl
    ~/.acme.sh/acme.sh  --register-account  --server zerossl \
    --eab-kid  $eab_kid \
    --eab-hmac-key  $eab_hmac_key
    ~/.acme.sh/acme.sh --dns dns_cf  --issue  -d $your_domain  --standalone
    ~/.acme.sh/acme.sh  --installcert  -d  $your_domain   \
        --key-file   /etc/nginx/ssl/$your_domain.key \
        --fullchain-file /etc/nginx/ssl/fullchain.cer
    newpath=$(cat /dev/urandom | head -1 | md5sum | head -c 4)
cat > /etc/nginx/conf.d/default.conf<<-EOF
server {
    listen 80;
    server_name banwa2.vlook.top;
    root /etc/nginx/html;
    index index.php index.html;
}
EOF
cat > /etc/systemd/system/nginx.service<<-EOF
[Unit]
Description=nginx service
After=network.target 
   
[Service] 
Type=forking 
ExecStart=/etc/nginx/sbin/nginx
ExecReload=/etc/nginx/sbin/nginx -s reload
ExecStop=/etc/nginx/sbin/nginx -s quit
PrivateTmp=true 
   
[Install] 
WantedBy=multi-user.target
EOF
chmod 777 /etc/systemd/system/nginx.service
systemctl enable nginx.service
}

#安装nginx
function install(){
    $systemPackage install -y wget curl unzip >/dev/null 2>&1
    green "======================="
    blue "请输入绑定到本VPS的域名"
    green "======================="
    read your_domain
    green "=========请输入eab_kid============="
    read eab_kid
    green "=========请输入eab_hmac_key=============="
    read eab_hmac_key
    real_addr=`ping ${your_domain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
    local_addr=`curl ipv4.icanhazip.com`
    if [ $real_addr == $local_addr ] ; then
        green "=========================================="
	green "         域名解析正常，开始安装"
	green "=========================================="
        install_nginx
    else
        red "===================================="
	red "域名解析地址与本VPS IP地址不一致"
	red "若你确认解析成功你可强制脚本继续运行"
	red "===================================="
	read -p "是否强制运行 ?请输入 [Y/n] :" yn
	[ -z "${yn}" ] && yn="y"
	if [[ $yn == [Yy] ]]; then
            green "强制继续运行脚本"
	    sleep 1s
	    install_nginx
	else
	    exit 1
	fi
    fi
}
#安装v2ray
function install_v2ray(){
    mkdir ~/.v2ray
    #echo "V2RAY_VMESS_AEAD_FORCED=false" > ~/.v2ray/v2_env
    #bash <(curl -L -s https://install.direct/go.sh)
    wget https://github.com/trojan-gfw/trojan/releases/download/v1.16.0/trojan-1.16.0-linux-amd64.tar.xz
    tar -xf trojan-1.16.0-linux-amd64.tar.xz
    mv trojan/trojan /usr/local/bin/trojan
    chmod 755 /usr/local/bin/trojan
    mkdir /etc/trojan/
    mv trojan/config.json  /etc/trojan/config.json
cat > /etc/systemd/system/trojan.service<<-EOF
[Unit]
Description=trojan
Documentation=https://trojan-gfw.github.io/config https://trojan-gfw.github.io/
After=network.target network-online.target

[Service]
Type=simple
StandardError=journal
ExecStart=trojan -c /etc/trojan/config.json
ExecReload=/bin/kill -HUP \$MAINPID
LimitNOFILE=51200
Restart=on-failure
RestartSec=1s

[Install]
WantedBy=multi-user.target
EOF


green "=============================="
green "         安装已经完成，请修改/etc/trojan/config.json"
green "         密码生成: openssl rand -base64 20"
green "===========配置参数============"
}

function remove_v2ray(){

    /etc/nginx/sbin/nginx -s stop
    systemctl stop v2ray.service
    systemctl disable v2ray.service
    
    rm -rf /usr/local/bin/v2ray /usr/local/bin/v2ctl
    rm -rf /usr/local/share/v2ray/ /usr/local/etc/v2ray/
    rm -rf /etc/systemd/system/v2ray*
    rm -rf /etc/nginx
    
    green "nginx、v2ray已删除"
    
}

function start_menu(){
    clear
    green " ==============================================="
    green " Info       : onekey script install v2ray+ws+tls        "
    green " OS support : centos7/debian9+/ubuntu16.04+                       "
    green " Author     : A                     "
    green " ==============================================="
    echo
    green " 1. Install trojan+ws+tls1.3"
    green " 2. Update v2ray"
    red " 3. Remove v2ray"
    yellow " 0. Exit"
    echo
    read -p "Pls enter a number:" num
    case "$num" in
    1)
    initenv
    check_os
    check_env
    install
    ;;
    2)
    bash <(curl -L -s https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
    systemctl restart v2ray
    ;;
    3)
    remove_v2ray 
    ;;
    0)
    exit 1
    ;;
    *)
    clear
    red "Enter the correct number"
    sleep 2s
    start_menu
    ;;
    esac
}

start_menu