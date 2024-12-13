# Check 3 arguments
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 ip user key"
    exit 1
fi

ip=$1
user_list=$2
key_list=$3

# 清理多餘的空行並將 user 列表處理成陣列
users=($(echo "$user_list" | awk 'NF > 0'))

# 將 key_list 處理成多行金鑰的陣列，以空行為分隔符
IFS=$'\n\n' read -rd '' -a keys <<< "$key_list"

# 分割 IP 和 Port，預設 Port 為 22
IFS=':' read -r IP PORT <<< "$ip"
PORT=${PORT:-22}

# 迭代處理每個 user 和對應的 key
for i in "${!users[@]}"; do
    user="${users[$i]}"
    key="${keys[$i]}"

    SSH="ssh -t -i /var/lib/jenkins/.ssh/id_rsa noc_jenkins@$IP -p $PORT"
    echo "Processing $user on $IP via port: $PORT"

    # 執行 SSH 命令
    $SSH << EOF
    user="$user"
    key="$key"
    user_home="/home/twnoc/\$user"
    ssh_dir="\$user_home/.ssh"
    authorized_keys="\$ssh_dir/authorized_keys"

    add_or_replace_key() {
        sudo mkdir -p "\$ssh_dir"
        sudo truncate -s 0 "\$authorized_keys"
        echo -e "\$key" | sudo tee "\$authorized_keys" > /dev/null
        sudo chown -R "\$user:twnoc" "\$user_home"
        sudo chmod 700 "\$ssh_dir"
        sudo chmod 600 "\$authorized_keys"
    }

    if id "\$user" &>/dev/null; then
        echo "User \$user exists. Replacing authorized_keys."
        add_or_replace_key
    else
        echo "User \$user does not exist for host \$IP. Creating user and setting up SSH key."
        sudo useradd "\$user" -md "\$user_home" -s /bin/bash -g twnoc
        add_or_replace_key
        sudo cp /etc/skel/.bash* "\$user_home/"
    fi
EOF