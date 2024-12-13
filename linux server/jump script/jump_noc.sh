#!/bin/bash
account=`whoami`
num=$1
echo ""
echo -e " =============================================================================================="
echo -e " ===========================Please choose the Svr you want to JUMP!!==========================="
echo -e " =============================================================================================="
echo ""
echo -e " [1]   ID_Proxy            IP:xxx.xxx.xxx.xxx:ssh_port          [1] App: ID_Proxy Svr"
echo ""
echo -e " =============================================================================================="
if [[ -z $num ]]
then
        read -p "Number:  " num
else
        echo $0
        des=`cat $0 | grep "\[$num\]" | sed -r "s/\[$num\]/#/g" | cut -d# -f2`
        clear
        echo "Jumping on [$num]$des"
fi
num=${num,,}
case $num in
        "1" | "aov")    ssh $account@xxx.xxx.xxx.xxx -p ssh_port     ;;
        *)      echo "Please enter correct number!!"    ;;
esac