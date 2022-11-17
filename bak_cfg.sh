#!/bin/bash
export DIR_CFG="/root/LinuxConfigFiles"
export LST_CFG="bak_cfg.lst"
export FILE=$DIR_CFG/$LST_CFG 
export USERNAME="debian"

config_shell(){
	if realpath "/bin/sh"|grep -q dash;then
        echo -e "\e[32mConfigure default shell from dash to bash on Debian OS...\e[0m"
		echo "dash dash/sh boolean false" | debconf-set-selections
		DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash
	fi
}

config_file_permission(){
    echo -e "\e[32mModify several user hidden file permission...\e[0m"
    #grep $USERNAME $FILE | xargs -n1 basename |xargs -p -i sh -c 'chown root:root {}; chmod 777 {}'
    grep $USERNAME $FILE | xargs -n1 basename |xargs -i sh -c 'chown ${USERNAME}:${USERNAME} {}; chmod 666 {}'
}

make_common_config(){
	config_shell
    config_file_permission

    ln -f $(pwd)/bak_cfg.sh /usr/local/bin/bak_cfg.sh
}


install_common_package(){
	[ -e sources.list ] && (cp sources.list /etc/apt/)

	echo -e "\e[32mInstalling several common useful APT package...\e[0m"
	apt update && apt install -y neofetch tree samba smbclient console-setup smem
}

restore_backuped_config(){
    for eachfile in $(cat $FILE)
    do
    	filename=$(basename $eachfile)
        echo -e "\e[32m\nRestore $filename to $eachfile\e[0m"
        case $filename in
        "timezone")                             #P1:timezone file
            cp -a $filename $eachfile
            rm    /etc/localtime
            echo -e "\e[32mNow configure the timezone to $(cat $eachfile)...\e[0m"
            dpkg-reconfigure -f noninteractive tzdata
            ;;
        "interfaces")				#P2:network IP
            cp -a $filename $eachfile
            systemctl restart networking
            ;;
        "sshd_config")				#P3:ssh server 
            cp -a $filename $eachfile
            systemctl restart sshd
            ;;
        ".vimrc")                   		#P4:.vimrc
            if [ ! -e $eachfile ]; then
                echo -e "\e[32m.vimrc not exist, try to install a good one\e[0m"
                su - $USERNAME << EOF
                git clone https://git.oschina.net/eccozhou/vimrc.git ~/.vim_runtime;
                sh ~/.vim_runtime/install_awesome_vimrc.sh;
                exit;
EOF
                chown $USERNAME:$USERNAME $filename
                chmod 666 $filename
                cp -a $filename $eachfile

                git clone https://git.oschina.net/eccozhou/vimrc.git ~/.vim_runtime;
                sh ~/.vim_runtime/install_awesome_vimrc.sh;
                rm -f /root/.vimrc
                ln /home/$USERNAME/.vimrc /root/.vimrc
            fi
            ;;
        "smb.conf")                 		#P5:smb.conf
            cp -a $filename $eachfile
            systemctl restart smbd
            ;;
        ".bashrc")                 		#P6:Home Debian bashrc
            chown $USERNAME:$USERNAME $filename
            chmod 666 $filename
            cp -a $filename $eachfile
            rm -f /root/.bashrc
            ln /home/$USERNAME/.bashrc /root/.bashrc
            ;;
        *)
            echo -e "\e[32mCommon Restore Process...\e[0m"
            cp -a $filename $eachfile
            ;;
        esac
    done
}

reboot(){
	if read -t 15 -p "Do you want to reboot? If no choice made,system will reboot after 15s.. (Yes/No)" answer; then
		case $answer in
			Y|y)
				echo "Reboot now..."
				reboot;;
			N|n)
				echo "Keep using...";;
		esac
	else
		echo "Reboot now..."
		reboot
	fi
}


backup_to_other_fs(){
    cd $DIR_CFG/.. && echo "Changed into Working Dir: $(pwd)"

	bakfile="bbb_configs.tgz"
	rm -f $bakfile
    tar -zpc -f $bakfile $(basename $DIR_CFG)/

	#To EMMC
	echo -e "\e[32mCopy to EMMC...\e[0m"
	mkdir -p /mnt/EMMC
	mount /dev/mmcblk1p1 /mnt/EMMC > /dev/null 2>&1
	cp -a $bakfile /mnt/EMMC/root/

	#To Windows
	echo -e "\e[32mCopy to Windows Share...\e[0m"
	smbclient -c "put $bakfile" //192.168.7.1/Backup -U lenovo%rambo || echo "Backup to Windows fail..."

    cd $DIR_CFG && echo "Changed into Working Dir: $(pwd)"
}


#Main Script Start
if ! id | grep -q root; then
    echo "This script must be run as root, try [sudo $0]"
    exit
fi

[ -e $DIR_CFG ] || mkdir -p $DIR_CFG

if [ $# -ne 1 ]; then                		#Only one Arg acceptted
    echo -e "Usage: sudo $0 \"filename\" 
    or sudo $0 backup 
    or sudo $0 restore\n"
elif [ $# -eq 1 ]; then 			#Main process

    #Backup
    if [ $1 = 'backup' ]; then        		
        echo -e "\e[32m\n###backup branch###\n\e[0m"
	if [ ! -e $FILE ]; then
        echo "list not exsit, you should use $0 [filename] to add config file first"
        exit
    fi

    for eachfile in $(cat $FILE)
    do
        echo -e "\e[32mBackup $eachfile to $DIR_CFG...\e[0m"
        cp -a -u $eachfile $DIR_CFG
    done
    backup_to_other_fs

    #Restore
    elif [ $1 = 'restore' ]; then 		
        echo -e "\e[32m\n###restore branch###\n\e[0m"
        cd $DIR_CFG && echo "Changed into Working Dir: $(pwd)"

	make_common_config
	install_common_package
	restore_backuped_config
    reboot

    #Add config file
    else					
        echo -e "\e[32m\n###Add config file branch###\n\e[0m"
        file=$(realpath -e $1)
        if [ $? -eq 0 ]; then
            echo $file >> $FILE
            echo -e "\e[32mNew Config File:[$file] added to $FILE\e[0m" 
            sort -u $FILE -o $FILE
        fi
    fi
fi
