#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m'

if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root"
    sleep .5
    exit 1
fi

config=''

read_input() {
    read -p "$1: " input
    if [ -z "$input" ]; then
        echo ""
        exit 1
    fi
    echo "$input"
}

if [ ! -f "xrayConfig.json" ]; then
	wget https://raw.githubusercontent.com/FarhadiAlireza/xrayRawConfig/main/rawConfig.json  && mv rawConfig.json xrayConfig.json
  echo 'The "xrayConfig.json" file has been created!'
  clear
elif [ -f "xrayConfig.json" ]; then
  echo -e 'The "xrayConfig.json" file exists!\n'
  sleep 1
fi

  if [[ -f /usr/local/bin/xray || -f /usr/bin/xray ]]; then
    echo "Seems like Xray is installed"
    sleep  1
    clear
else
    echo -e "Xray is not installed"
    sleep 0.3
    echo -e "Would you like to install Xray or go on without it?"
    read -p "Hint: To install, Press (y), Otherwise press (n) : " install_xray
  if [ "$install_xray" == "y" ]; then
      clear
      bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --beta -u root
     if xray --version > /dev/null 2>&1; then
       sleep 2
       echo "Xray installed successfully"
     else
       sleep 2
       echo "Xray install failed" >&2
       exit 1
     fi
  else(echo  "ATTENTION: May be some commands doesn't work well" sleep 2)
  fi
fi

echo "Running as root..."
echo "Let's Go..."
sleep 0.8
clear

echo -e "                                       "
echo -e "${RED}█▓▒▒░░░XRAY-CORE░░░▒▒▓█          "
echo -e "                                       "
echo -e "                                       "
echo -e "${MAGENTA}Please choose an option:${NC}"
echo -e "                                       "
echo -e "                                       "
echo -e "    ${GREEN}--Vless Config--           "
echo -e "                                       "
echo -e "${RED}1) ${YELLOW}VLESS With TLS"
echo -e "                                       "
echo -e "${RED}2) ${YELLOW}VLESS Without TLS"
echo -e "                                       "
echo -e "${RED}3) ${YELLOW}VLESS With REALITY"
echo -e "                                       "
echo -e "---------------------------------------"
echo -e "                                       "
echo -e "    ${GREEN}--Vmess Config--           "
echo -e "                                       "
echo -e "${RED}4) ${YELLOW}VMESS With TLS"
echo -e "                                       "
echo -e "${RED}5) ${YELLOW}VMESS Without TLS"
echo -e "                                       "
echo -e "---------------------------------------"
echo -e "                                       "
echo -e "    ${GREEN}--Trojan Config--          "
echo -e "                                       "
echo -e "${RED}6) ${YELLOW}TROJAN With TLS"
echo -e "                                       "
echo -e "${RED}7) ${YELLOW}TROJAN Without TLS"
echo -e "                                       "
echo -e "${RED}8) ${YELLOW}TROJAN With REALITY"
echo -e "                                       "
echo -e "                                       "

read -p "Enter option number: " choice

#////Functions////#

generate_ca () {
  mkdir "certKeys"
  openssl ecparam -genkey -name prime256v1 -out /root/certKeys/ca.key
  openssl req -new -x509 -days 36500 -key /root/certKeys/ca.key -out /root/certKeys/ca.crt  -subj "/CN=bing.com"
  caKeyPath="/root/certKeys/ca.key"
  caCrtPath="/root/certKeys/ca.crt"
}

check_port() {
  local port=$1

  if [[ $port =~ ^[0-9]+$ ]]; then
    if sudo lsof -i :"$port" > /dev/null 2>&1; then
      echo "Port $port is listening."
      return 0
    else
      echo "Port $port is not listening."
      return 1
    fi
  else
    echo "Error: Invalid port '$port'" >&2
    return 1
  fi
}

generate_uuid() {
  xray uuid
}

generate_pKey() {
  xray x25519
}

generate_shortId() {
  openssl rand -hex 16
}


protocol_section() {
  port=$1
  protocol=$2
  str=$(cat <<EOF
{
   \"listen\": null,
   \"port\": $port,
   \"protocol\": \"$protocol\",
   \"settings\":{
      \"clients\": [
EOF
)
  echo "$str"
}

vless_client() {
  username=$1
  str=$(cat <<EOF
          {
            \"email\": \"$username\",
            \"id\": \"$(generate_uuid)\"
          },
EOF
)
echo "$str"
}

trojan_client(){
  username=$1
  str=$(cat <<EOF
          {
            \"email\": \"$username\",
            \"password\": \"$(generate_uuid)\"
          },
EOF
)
echo "$str"
}

vmess_client(){
  username=$1
  str=$(cat <<EOF
          {
            \"email\": \"$username\",
            \"id\": \"$(generate_uuid)\"
          },
EOF
)
echo "$str"
}

stream_setting(){
  network=$1
  security=$2
  str=$(cat <<EOF
     \"streamSettings\": {
        \"network\": \"$network\",
        \"security\": \"$security\",
EOF
)
echo "$str"
}

ws_noTls(){
  path=$1
  host=$2
  str=$(cat <<EOF
      \"wsSettings\": {
        \"path\": \"$path\",
        \"headers\": {
          \"host\": \"$host\"
        }
       },
EOF
)
echo "$str"
}

ws_tls(){
  path=$1
  host=$2
  server_name=$3
  alpn=$4
  fingerprint=$5
  str=$(cat <<EOF
      \"wsSettings\": {
        \"path\": \"$path\",
        \"headers\": {
          \"host\": \"$host\"
         }
       },
      \"tlsSettings\": {
        \"serverName\": \"$server_name\",
        \"minVersion\": \"1.2\",
        \"maxVersion\": \"1.3\",
        \"cipherSuites\": \"\",
        \"rejectUnknownSni\": false,
        \"certificates\": [
          {
              \"certificateFile\": \"$caCrtPath\",
              \"keyFile\": \"$caKeyPath\"
          }
        ],
        \"alpn\": [
          \"$alpn\"
          ],
        \"settings\": {
          \"allowInsecure\": false,
          \"fingerprint\": \"$fingerprint\",
          \"domains\": []
         }
      }
EOF
)
echo "$str"
}

grpc_noTls(){
  serviceName=$1
  str=$(cat <<EOF
      \"grpcSettings\": {
        \"serviceName\": \"$serviceName\",
        \"multiMode\": false
        \"settings\": {
          \"allowInsecure\": false,
          \"domains\": []
         }
      }
EOF
)
echo "$str"
}

grpc_tls(){
  serviceName=$1
  server_name=$2
  certificate_file=$3
  key_file=$4
  alpn=$5
  fingerprint=$6
  str=$(cat <<EOF
      \"grpcSettings\": {
        \"serviceName\": \"$serviceName\",
        \"multiMode\": false
       },
      \"tlsSettings\": {
        \"serverName\": \"$server_name\",
        \"minVersion\": \"1.2\",
        \"maxVersion\": \"1.3\",
        \"cipherSuites\": \"\",
        \"rejectUnknownSni\": false,
        \"certificates\": [
           {
              \"certificateFile\": \"$caCrtPath\",
              \"keyFile\": \"$caKeyPath\"
           }
        ],
        \"alpn\": [
          \"$alpn\"
         ],
        \"settings\": {
          \"allowInsecure\": false,
          \"serverName\": \"$server_name\",
          \"fingerprint\": \"$fingerprint\",
          \"domains\": []
        }
      }
EOF
)
echo "$str"
}

grpc_reality(){
  serviceName=$1
  dest=$2
  server_names=$3
  short_ids=$4
  fingerprint=$5
  spider_x=$6
  str=$(cat <<EOF
      \"grpcSettings\": {
        \"serviceName\": \"$serviceName\",
        \"multiMode\": false
       },
     \"realitySettings\": {
        \"xver\": 0,
        \"show\": false,
        \"dest\": \"$dest\",
        \"serverNames\": [$server_names],
        \"shortIds\": \"$(generate_shortId)\",
        \"fingerprint\": \"$fingerprint\",
        \"privateKey\": \"$(generate_pKey | awk '/Private key:/ {print $NF}')\",
        \"publicKey\": \"$(generate_pKey | awk '/Public key:/ {print $NF}')\",
        \"minClientVer\": \"\",
        \"maxClientVer\": \"\",
        \"maxTimeDiff\": 0,
        \"spiderX\": \"$spider_x\"
      }
EOF
)
echo "$str"
}

tcp_noTls(){
  str=$(cat <<EOF
        \"TCPSettings\": {
         \"acceptProxyProtocol\": false,
          \"header\": {
            \"type\": \"none\"
          }
        }
EOF
)
echo "$str"
}

tcp_tls(){
  alpn=$1
  certificate_file=$2
  key_file=$3
  serviceName=$4
  fingerprint=$5
  server_name=$6
  str=$(cat <<EOF
          \"TCPSettings\": {
            \"acceptProxyProtocol\": false,
            \"header\": {
              \"type\": \"none\"
            }
          }, 
          \"tlsSettings\": {
            \"alpn\": [
              \"$alpn\"
            ],
            \"certificates\": [
               {
              \"certificateFile\": \"$caCrtPath\",
              \"keyFile\": \"$caKeyPath\"
               }
             ],
            \"cipherSuites\": "",
            \"maxVersion\": \"1.3\",
            \"minVersion\": \"1.2\",
            \"rejectUnknownSni\": false,
            \"serviceName\": \"$serviceName\",
            \"settings\": {
              \"allowInsecure\": false,
              \"domains\": [],
              \"fingerprint\": \"$fingerprint\",
              \"serverName\": \"$server_name\",
            }
          }
        }
EOF
)
echo "$str"
}

tcp_reality(){
  dest=$1
  server_names=$2
  fingerprint=$3
  spider_x=$4
  str=$(cat <<EOF
          \"TCPSettings\": {
           \"acceptProxyProtocol\": false,
            \"header\": {
              \"type\": \"none\"
            }
          }
         \"realitySettings\": {
           \"xver\": 0,
           \"show\": false,
           \"dest\": \"$dest\",
           \"serverNames\": [$server_names],
           \"shortIds\": "$(openssl rand -hex 8)",
           \"fingerprint\": \"$fingerprint\",
           \"privateKey\": \"$(generate_pKey | awk '/Private key:/ {print $NF}')\",
           \"publicKey\": \"$(generate_pKey | awk '/Public key:/ {print $NF}')\",
           \"minClientVer\": \"\",
           \"maxClientVer\": \"\",
           \"maxTimeDiff\": 0,
           \"spiderX\": \"$spider_x\"
         }
EOF
)
echo "$str"
}

generate_ca

case $choice in
  1)
	echo -e "                                       "
    echo -e "${GREEN}VLESS With TLS"
	echo -e "                                       "
    protocol="vless"
    security="tls"
    echo -e "1) GRPC"
    echo -e "2) WS"
    echo -e "3) TCP"
	echo -e "                                       "
    read -p "Please enter the option number: " network
    case $network in
      1) network="grpc" ;;
      2) network="ws" ;;
      3) network="tpc"
    esac
    port=$(read_input "Enter Port => " "Port")
    num_clients=$(read_input "Enter Number of clients => " "Number of Clients")
    config+=$(protocol_section "$port" "$protocol")
  for ((i = 1; i <= num_clients; i++)); do
    read -p "Enter Username for client($i) => " username
    read -p "Enter UUID for client($i) or The system fills automatically => " id
    if [ -z "$id" ]; then
        uuid=$(xray uuid)
        id="$uuid"
    fi
    config+=$(vless_client "$username" "$id")
  done
config=${config%,*}
config+="
      ]
    },
"
			echo -e "                                       "
            echo -e "Select Your Fingerprint"
            echo -e "                                       "
          	echo -e "${YELLOW}1)  Chrome"
          	echo -e "                                       "
            echo -e "${YELLOW}2)  Firefox"
          	echo -e "                                       "
          	echo -e "${YELLOW}3)  Safari"
          	echo -e "                                       "
          	echo -e "${YELLOW}4)  Android"
          	echo -e "                                       "
          	echo -e "${YELLOW}5)  Ios"
          	echo -e "                                       "
          	echo -e "${YELLOW}6)  Edge"
          	echo -e "                                       "
          	echo -e "${YELLOW}7)  360"
          	echo -e "                                       "
          	echo -e "${YELLOW}8)  qq"
          	echo -e "                                       "
          	echo -e "${YELLOW}9)  random"
          	echo -e "                                      "
          	echo -e "${YELLOW}10) randomize"
            echo -e "                                        "
            echo -e "${YELLOW}11) I don't need"
            echo -e "                                       "
            read -p "Enter option number: " fingerprint

case $fingerprint in
    1)
      fingerprint="chrome"
      ;;
    2)
      fingerprint="firefox"
      ;;
    3)
      fingerprint="safari"
      ;;
    4)
      fingerprint="android"
      ;;
    5)
      fingerprint="ios"
      ;;
    6)
      fingerprint="edge"
      ;;
    7)
      fingerprint="360"
      ;;
    8)
      fingerprint="qq"
      ;;
    9)
      fingerprint="random"
      ;;
    10)
      fingerprint="randomize"
      ;;
    11)
      fingerprint=""
      ;;
esac

config+=$(stream_setting "$network" "$security")

if [ "$security" == "tls" ] && [ "$network" == "ws" ]; then
    server_name=$(read_input "Enter Server Name (SNI) => " "Server Name")
#    certificate_file=$(read_input "Enter Certificate File => " "Certificate File")
#    key_file=$(read_input "Enter Key File => " "Key File")
    alpn=$(read_input "Enter ALPN ( 1-http/1.1  2-h2  3-http/1.1,h2 ) => " "ALPN")
    path=$(read_input "Enter path => " "Path")
    host=$(read_input "Enter host => " "Host")
    if [ "$alpn" == 1 ]; then
        alpn='http/1.1'
    elif [ "$alpn" = 2 ]; then
        alpn='h2'
    elif [ "$alpn" == 3 ]; then
        alpn='http/1.1,h2'
    fi

config+=$(ws_tls "$path" "$host" "$server_name" "$certificate_file" "$key_file" "$alpn" "$fingerprint" )

elif [ "$security" == "tls" ] && [ "$network" == "grpc" ]; then
    server_name=$(read_input "Enter Server Name (SNI) => " "Server Name")
    serviceName=$(read_input "Enter Service Name => " " Service Name")
#    certificate_file=$(read_input "Enter Certificate File => " "Certificate File")
#    key_file=$(read_input "Enter Key File:" "Key File")
    alpn=$(read_input "Enter ALPN ( 1-http/1.1  2-h2  3-http/1.1,h2 ) => " "ALPN")
    if [ "$alpn" == 1 ]; then
        alpn='http/1.1'
    elif [ "$alpn" = 2 ]; then
        alpn='h2'
    elif [ "$alpn" == 3 ]; then
        alpn='http/1.1,h2'
    fi
config+=$(grpc_tls "$serviceName" "$server_name" "$certificate_file" "$key_file" "$alpn" "$fingerprint"  )
elif [ "$security" == "tls" ] && [ "$network" == "tcp" ]; then
config+=$(tcp_tls "$alpn" "$certificate_file" "$key_file" "$serviceName" "$fingerprint" "$server_name")
  fi
;;
  2)
    echo -e "                                       "
    echo -e "${GREEN}VLESS Without TLS"
	echo -e "                                       "
    protocol="vless"
    security=""
    echo -e "1) GRPC"
    echo -e "2) WS"
    echo -e "3) TCP"
	echo -e "                                       "
      read -p "Please enter the option number: " network
      read -p "Enter Port => " port
      read -p "Enter Number of clients => " num_clients
      case $network in
        1) network="grpc" ;;
        2) network="ws" ;;
        3) network="tpc"
      esac
config+=$(protocol_section "$port" "$protocol")
    for ((i = 1; i <= num_clients; i++)); do
      read -p "Enter Username for client($i) => " username
      read -p "Enter UUID for client($i) or The system fills automatically => " id
      if [ -z "$id" ]; then
          uuid=$(xray uuid)
          id="$uuid"
      fi
config+=$(vless_client "$username" "$id")
    done
  config=${config%,*}
  config+="
    ]
        },
  "
config+=$(stream_setting "$network" "$security")
  if [ "$network" == "ws" ]; then
      path=$(read_input "Enter path => " "Path")
      host=$(read_input "Enter host => " "Host")

config+=$(ws_noTls "$path" "$host")
  elif [ "$network" == "grpc" ]; then
      serviceName=$(read_input "Enter Service Name => " " Service Name")
config+=$(grpc_noTls "$serviceName")
  elif [ "$network" == "tcp" ]; then
config+=$(tcp_noTls)
fi
;;

    3)
		echo -e "                                       "
		echo -e "${GREEN}VLESS With REALITY"
		echo -e "                                       "
		protocol="vless"
		security="reality"
		echo -e "1) GRPC"
		echo -e "2) TCP"
		echo -e "                                       "
          case $network in
            1) network="grpc" ;;
            2) network="tpc"
          esac
          read -p "Please enter the option number: " network
          read -p "Enter Port => " port
          read -p "Enter Number of clients => " num_clients

config+=$(protocol_section "$port" "$protocol")
            for ((i = 1; i <= num_clients; i++)); do
              read -p "Enter Username for client($i) => " username
              read -p "Enter UUID for client($i) or The system fills automatically => " id
              if [ -z "$id" ]; then
                  uuid=$(xray uuid)
                  id="$uuid"
              fi
config+=$(vless_client "$username" "$id")
            done
          config=${config%,*}
          config+="
            ]
                },
          "
			echo -e "                                       "
            echo -e "Select Your Fingerprint"
            echo -e "                                       "
          	echo -e "${YELLOW}1)  Chrome"
          	echo -e "                                       "
            echo -e "${YELLOW}2)  Firefox"
          	echo -e "                                       "
          	echo -e "${YELLOW}3)  Safari"
          	echo -e "                                       "
          	echo -e "${YELLOW}4)  Android"
          	echo -e "                                       "
          	echo -e "${YELLOW}5)  Ios"
          	echo -e "                                       "
          	echo -e "${YELLOW}6)  Edge"
          	echo -e "                                       "
          	echo -e "${YELLOW}7)  360"
          	echo -e "                                       "
          	echo -e "${YELLOW}8)  qq"
          	echo -e "                                       "
          	echo -e "${YELLOW}9)  random"
          	echo -e "                                      "
          	echo -e "${YELLOW}10) randomize"
            echo -e "                                        "
            echo -e "${YELLOW}11) I don't need"
            echo -e "                                       "
            read -p "Enter option number: " fingerprint

          case $fingerprint in
              1)
                fingerprint="chrome"
                ;;
              2)
                fingerprint="firefox"
                ;;
              3)
                fingerprint="safari"
                ;;
              4)
                fingerprint="android"
                ;;
              5)
                fingerprint="ios"
                ;;
              6)
                fingerprint="edge"
                ;;
              7)
                fingerprint="360"
                ;;
              8)
                fingerprint="qq"
                ;;
              9)
                fingerprint="random"
                ;;
              10)
                fingerprint="randomize"
                ;;
              11)
                fingerprint=""
                ;;
          esac

          dest=$(read_input "Enter dest => " "Dest")
          server_names=$(read_input "Enter serverNames => " "Server Names (comma-separated)")
          spider_x=$(read_input "Enter spiderX => " "Spider X")
              if [ "$network" == "tcp" ]; then
config+=$(tcp_reality "$dest" "$server_names" "$fingerprint" "$spider_x")
              elif [ "$network" == "grpc" ]; then
config+=$(grpc_reality "$serviceName" "$dest" "$server_names" "$short_ids" "$fingerprint" "$spider_x" )
              fi
  ;;
  4)
      echo -e "                                       "
      echo -e "${GREEN}VMESS With TLS"
	  echo -e "                                       "
      protocol="vmess"
      security="tls"
      echo -e "1) GRPC"
      echo -e "2) WS"
      echo -e "3) TCP"
      case $network in
        1) network="grpc" ;;
        2) network="ws" ;;
        3) network="tpc"
      esac
      read -p "Please enter the option number: " network
      read -p "Enter Port => " port
      read -p "Enter Number of clients => " num_clients

config+=$(protocol_section "$port" "$protocol")
        for ((i = 1; i <= num_clients; i++)); do
          read -p "Enter Username for client($i) => " username
          read -p "Enter UUID for client($i) or The system fills automatically => " id
          if [ -z "$id" ]; then
              uuid=$(xray uuid)
              id="$uuid"
          fi
config+=$(vmess_client "$username" "$id")
        done
      config=${config%,*}
      config+="
        ]
            },
      "
			echo -e "                                       "
            echo -e "Select Your Fingerprint"
            echo -e "                                       "
          	echo -e "${YELLOW}1)  Chrome"
          	echo -e "                                       "
            echo -e "${YELLOW}2)  Firefox"
          	echo -e "                                       "
          	echo -e "${YELLOW}3)  Safari"
          	echo -e "                                       "
          	echo -e "${YELLOW}4)  Android"
          	echo -e "                                       "
          	echo -e "${YELLOW}5)  Ios"
          	echo -e "                                       "
          	echo -e "${YELLOW}6)  Edge"
          	echo -e "                                       "
          	echo -e "${YELLOW}7)  360"
          	echo -e "                                       "
          	echo -e "${YELLOW}8)  qq"
          	echo -e "                                       "
          	echo -e "${YELLOW}9)  random"
          	echo -e "                                      "
          	echo -e "${YELLOW}10) randomize"
            echo -e "                                        "
            echo -e "${YELLOW}11) I don't need"
            echo -e "                                       "
            read -p "Enter option number: " fingerprint

      case $fingerprint in
          1)
            fingerprint="chrome"
            ;;
          2)
            fingerprint="firefox"
            ;;
          3)
            fingerprint="safari"
            ;;
          4)
            fingerprint="android"
            ;;
          5)
            fingerprint="ios"
            ;;
          6)
            fingerprint="edge"
            ;;
          7)
            fingerprint="360"
            ;;
          8)
            fingerprint="qq"
            ;;
          9)
            fingerprint="random"
            ;;
          10)
            fingerprint="randomize"
            ;;
          11)
            fingerprint=""
            ;;
      esac

config+=$(stream_setting "$network" "$security")
      if [ "$security" == "tls" ] && [ "$network" == "ws" ]; then
          server_name=$(read_input "Enter Server Name (SNI) => " "Server Name")
#          certificate_file=$(read_input "Enter Certificate File => " "Certificate File")
#          key_file=$(read_input "Enter Key File => " "Key File")
          alpn=$(read_input "Enter ALPN ( 1-http/1.1  2-h2  3-http/1.1,h2 ) => " "ALPN")
          path=$(read_input "Enter path => " "Path")
          host=$(read_input "Enter host => " "Host")
          if [ "$alpn" == 1 ]; then
              alpn='http/1.1'
          elif [ "$alpn" = 2 ]; then
              alpn='h2'
          elif [ "$alpn" == 3 ]; then
              alpn='http/1.1,h2'
          fi

config+=$(ws_tls "$path" "$host" "$server_name" "$certificate_file" "$key_file" "$alpn" "$fingerprint" )

      elif [ "$security" == "tls" ] && [ "$network" == "grpc" ]; then
          server_name=$(read_input "Enter Server Name (SNI) => " "Server Name")
          serviceName=$(read_input "Enter Service Name => " " Service Name")
          certificate_file=$(read_input "Enter Certificate File => " "Certificate File")
          key_file=$(read_input "Enter Key File:" "Key File")
          alpn=$(read_input "Enter ALPN ( 1-http/1.1  2-h2  3-http/1.1,h2 ) => " "ALPN")
          if [ "$alpn" == 1 ]; then
              alpn='http/1.1'
          elif [ "$alpn" = 2 ]; then
              alpn='h2'
          elif [ "$alpn" == 3 ]; then
              alpn='http/1.1,h2'
          fi

config+=$(grpc_tls "$serviceName" "$server_name" "$certificate_file" "$key_file" "$alpn" "$fingerprint"  )

      elif [ "$security" == "tls" ] && [ "$network" == "tcp" ]; then

config+=$(tcp_tls "$alpn" "$certificate_file" "$key_file" "$serviceName" "$fingerprint" "$server_name")

    fi
  ;;
  5)
		  echo -e "                                       "
          echo -e "${GREEN}VMESS Without TLS"
		  echo -e "                                       "
          protocol="vmess"
          security=""
          echo -e "1) GRPC"
          echo -e "2) WS"
          echo -e "3) TCP"
          read -p "Please enter the option number: " network
          read -p "Enter Port => " port
          read -p "Enter Number of clients => " num_clients
          case $network in
            1) network="grpc" ;;
            2) network="ws" ;;
            3) network="tpc"
          esac
          
config+=$(protocol_section "$port" "$protocol")

        for ((i = 1; i <= num_clients; i++)); do
          read -p "Enter Username for client($i) => " username
          read -p "Enter UUID for client($i) or The system fills automatically => " id
          if [ -z "$id" ]; then
              uuid=$(xray uuid)
              id="$uuid"
          fi
config+=$(vmess_client "$username" "$id")
        done
      config=${config%,*}
      config+="
        ]
            },
      "
config+=$(stream_setting "$network" "$security")
      if [ "$network" == "ws" ]; then
          path=$(read_input "Enter path => " "Path")
          host=$(read_input "Enter host => " "Host")
config+=$(ws_noTls "$path" "$host")
      elif [ "$network" == "grpc" ]; then
          serviceName=$(read_input "Enter Service Name => " " Service Name")
          config+=$(grpc_noTls "$serviceName")
      elif [ "$network" == "tcp" ]; then
config+=$(tcp_noTls)
    fi
    ;;
  6)
    echo -e "                                       "
    echo -e "${GREEN}TROJAN With TLS"
	echo -e "                                       "
    protocol="trojan"
    security="tls"
    echo -e "1) GRPC"
    echo -e "2) WS"
    echo -e "3) TCP"
    case $network in
      1) network="grpc" ;;
      2) network="ws" ;;
      3) network="tpc"
    esac
    read -p "Please enter the option number: " network
    port=$(read_input "Enter Port => " "Port")
    num_clients=$(read_input "Enter Number of clients => " "Number of Clients")
config+=$(protocol_section "$port" "$protocol")
  for ((i = 1; i <= num_clients; i++)); do
    read -p "Enter Username for client($i) => " username
    read -p "Enter UUID for client($i) or The system fills automatically => " password
    if [ -z "$password" ]; then
        uuid=$(xray uuid)
        password="$uuid"
    fi
config+=$(trojan_client "$username" "$password")
  done
config=${config%,*}
config+="
  ]
      },
"
  echo -e "Select Your Fingerprint"
  echo "||--------------- ||"
	echo -e "${YELLOW}1) ==> Chrome"
	echo -e "                                       "
  echo -e "${YELLOW}2) ==> Firefox"
	echo -e "                                       "
	echo -e "${YELLOW}3) ==> Safari"
	echo -e "                                       "
	echo -e "${YELLOW}4) ==> Android"
	echo -e "                                       "
	echo -e "${YELLOW}5) ==> Ios"
	echo -e "                                       "
	echo -e "${YELLOW}6) ==> Edge"
	echo -e "                                       "
	echo -e "${YELLOW}7) ==> 360"
	echo -e "                                       "
	echo -e "${YELLOW}8) ==> qq"
	echo -e "                                       "
	echo -e "${YELLOW}9) ==> random"
	echo -e "                                       "
	echo -e "${YELLOW}10) ==> randomize"
  echo -e "                                       "
  echo -e "${YELLOW}11) ==> I don't need"
  echo -e "                                       "
  read -p "Enter option number: " fingerprint

case $fingerprint in
    1)
      fingerprint="chrome"
      ;;
    2)
      fingerprint="firefox"
      ;;
    3)
      fingerprint="safari"
      ;;
    4)
      fingerprint="android"
      ;;
    5)
      fingerprint="ios"
      ;;
    6)
      fingerprint="edge"
      ;;
    7)
      fingerprint="360"
      ;;
    8)
      fingerprint="qq"
      ;;
    9)
      fingerprint="random"
      ;;
    10)
      fingerprint="randomize"
      ;;
    11)
      fingerprint=""
      ;;
esac

config+=$(stream_setting "$network" "$security")

if [ "$security" == "tls" ] && [ "$network" == "ws" ]; then
    server_name=$(read_input "Enter Server Name (SNI) => " "Server Name")
#    certificate_file=$(read_input "Enter Certificate File => " "Certificate File")
#    key_file=$(read_input "Enter Key File => " "Key File")
    alpn=$(read_input "Enter ALPN ( 1-http/1.1  2-h2  3-http/1.1,h2 ) => " "ALPN")
    path=$(read_input "Enter path => " "Path")
    host=$(read_input "Enter host => " "Host")
    if [ "$alpn" == 1 ]; then
        alpn='http/1.1'
    elif [ "$alpn" = 2 ]; then
        alpn='h2'
    elif [ "$alpn" == 3 ]; then
        alpn='http/1.1,h2'
    fi

config+=$(ws_tls "$path" "$host" "$server_name" "$certificate_file" "$key_file" "$alpn" "$fingerprint" )

elif [ "$security" == "tls" ] && [ "$network" == "grpc" ]; then
    server_name=$(read_input "Enter Server Name (SNI) => " "Server Name")
    serviceName=$(read_input "Enter Service Name => " " Service Name")
#    certificate_file=$(read_input "Enter Certificate File => " "Certificate File")
#    key_file=$(read_input "Enter Key File:" "Key File")
    alpn=$(read_input "Enter ALPN ( 1-http/1.1  2-h2  3-http/1.1,h2 ) => " "ALPN")
    if [ "$alpn" == 1 ]; then
        alpn='http/1.1'
    elif [ "$alpn" = 2 ]; then
        alpn='h2'
    elif [ "$alpn" == 3 ]; then
        alpn='http/1.1,h2'
    fi
config+=$(grpc_tls "$serviceName" "$server_name" "$certificate_file" "$key_file" "$alpn" "$fingerprint")
elif [ "$security" == "tls" ] && [ "$network" == "tcp" ]; then
config+=$(tcp_tls "$alpn" "$certificate_file" "$key_file" "$serviceName" "$fingerprint" "$server_name")
  fi
;;
  7)
	  echo -e "                                       "
      echo -e "${GREEN}TROJAN Without TLS"
	  echo -e "                                       "
      protocol="trojan"
      security=""
      echo -e "1) GRPC"
      echo -e "2) WS"
      echo -e "3) TCP"
      case $network in
        1) network="grpc" ;;
        2) network="ws" ;;
        3) network="tpc"
      esac
      read -p "Please enter the option number: " network
      read -p "Enter Port => " port
      read -p "Enter Number of clients => " num_clients

config+=$(protocol_section "$port" "$protocol")

    for ((i = 1; i <= num_clients; i++)); do
      read -p "Enter Username for client($i) => " username
      read -p "Enter UUID for client($i) or The system fills automatically => " password
      if [ -z "$password" ]; then
          uuid=$(xray uuid)
          password="$uuid"
      fi
config+=$(trojan_client "$username" "$password")
    done
  config=${config%,*}
  config+="
    ]
        },
  "
config+=$(stream_setting "$network" "$security")
  if [ "$network" == "ws" ]; then
      path=$(read_input "Enter path => " "Path")
      host=$(read_input "Enter host => " "Host")

config+=$(ws_noTls "$path" "$host")
  elif [ "$network" == "grpc" ]; then
      serviceName=$(read_input "Enter Service Name => " " Service Name")
config+=$(grpc_noTls "$serviceName")
  elif [ "$network" == "tcp" ]; then
config+=$(tcp_noTls)
fi
;;

esac

config+="
   }
  },
"

tmpfile=$(mktemp)

awk -v config="$config" 'match($0, /^\s*"inbounds":/) {p=1; print; print config; next} p{p=0} 1' xrayConfig.json > "$tmpfile"

mv "$tmpfile" xrayConfig.json
echo "Configuration saved into xrayConfig.json"
