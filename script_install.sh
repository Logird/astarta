#!/bin/bash

#Скрипт подготовки сервера к инсталяции IP-ATC

#############################################################################
############################ПОДГОТОВИТЕЛЬНЫЙ ЭТАП############################
#############################################################################
#Настройки интерфейса eth0
IP0='197.168.211.254'
PREFIX0=24
GATEWAY0='197.168.211.251'
DNS10='197.168.211.251'

#Настройки интерфейса eth1
IP1='10.10.10.254'
PREFIX1=24
MACADDR1='00:00:10:10:FE:FE'

SCRIPTPWD=$PWD

#что копировать
#Создание временного файла с текущими названиями интерфейсов
ls /etc/sysconfig/network-scripts/ifcfg-e* | cut -d : -f 1 > ethname
cat /sys/class/net/e*/address > macname

alias cp
#Копирование без подтверждения замены файлов
unalias cp

#LABEL CONFIG ETHERNET
confeth_manual(){
case $2 in
	0) echo HWADDR=`sed -n 1p macname` >> $1
	;;
	1) echo HWADDR=`sed -n 2p macname` >> $1
esac
nano $1
}

confeth_auto(){
  MAC1=`sed -n 1p macname`
  sed -i '/ONBOOT=/d' $i
  sed -i '/BOOTPROTO=/d' $i
  sed -i 'UUID=/d' $1
  echo BOOTPROTO=none >> $i
  echo ONBOOT=yes >> $i
  echo "путь к интерфейсу"
	echo $1
	echo "номер интерфейса"
	echo $2
case $2 in
	0) sed -i '/IPADDR=/d' $1
	sed -i '/PREFIX=/d' $1
	sed -i '/GATEWAY=/d' $1
	sed -i '/DNS1=/d' $1
    echo IPADDR=`echo $IP0` >> $1
	echo PREFIX=`echo $PREFIX0` >> $1
	echo GATEWAY=`echo $GATEWAY0` >> $1
	echo DNS1=`echo $DNS10` >> $1
	echo HWADDR=`sed -n 1p macname` >> $1
	;;
	1) sed -i '/IPADDR=/d' $1
	sed -i '/PREFIX=/d' $1
	sed -i '/GATEWAY=/d' $1
	sed -i '/DNS1=/d' $1
    echo IPADDR=`echo $IP1` >> $1
	echo PREFIX=`echo $PREFIX1` >> $1
	#echo MACADDR=`echo $MACADDR1` >> $1
	echo HWADDR=`sed -n 2p macname` >> $1
	;;
esac
}

confeth (){
tput setaf 3
echo "Типы настройки сетевых интерфейсов:"
echo "auto (a) - автоматическая настройка"
echo "первый интерфейс IP 197.168.211.254/24. Предназначен для управления и регистрации SIP абонентов"
echo "второй интерфейс IP 10.10.10.254/24. Предназначен для работы с платами PCM"
echo "manual (m) - настройка вручную. Конфигурационные файлы будут открыты для самостоятельного редактирования"
echo
tput sgr0
echo "Настраиваемые интерфейсы: "
echo `cat ./ethname`
j=0
for i in `cat ./ethname`
do
  if [ $j -lt 2 ]; then 
	echo -n "Выберите тип настройки `echo $i` авто/вручную (a/m):  "
	read item
	case "$item" in 
	  a|A) echo "Автоматическая настройка `echo $i`"
	  confeth_auto $i $j
	  ;;
	  m|M) echo "Ручная настройка `echo $i`"
	  sleep 2s
	  confeth_manual $i $j
	  ;;
	  *) echo "Введен неверный символ. Повтор шага...."
	  confeth
	  ;;
	esac
  else echo "Интерфейсы настроены"
  fi
j=`expr $j + 1`
done
echo "Удаление вспомогательных файлов"
rm -f ./ethname
echo "Попытка перезапуска сетевых интерфейсов"
systemctl restart network.service
if [ $? -eq 0 ]; then
	echo 'Сетевые интерфейсы перезапущены.'
	else echo 'Ошибка перезапуска сетевых интерфейсов. После выполнения скрипта перезапустите интерфейсы вручную'
fi
}

#LABEL CONFIG LOCALE CP1251
conflocale(){
	sed -i '/KEYMAP=/d' /etc/vconsole.conf 
	sed -i '/FONT_MAP=/d' /etc/vconsole.conf
	echo KEYMAP="ruwin_alt-CP1251" >> /etc/vconsole.conf
	echo FONT_MAP="cp1251_to_uni" >> /etc/vconsole.conf
	
	if ! (grep -aq systemctl /etc/rc.local); then
	echo "Изменение файла /etc/rc.local"
	echo systemctl restart systemd-vconsole-setup >> /etc/rc.local
	else
	echo "Файл /etc/rc.local не нуждается в модификации"
	fi
	echo "Изменение прав доступа к файлам /etc/rc.local и /etc/rc.d/rc.local"
	chmod +x /etc/rc.local
	chmod +x /etc/rc.d/rc.local
	echo "Изменение файла /etc/locale.conf"
	sed -i '/LANG=/d' /etc/locale.conf
	echo LANG="ru_RU.cp1251" >> /etc/locale.conf
	
	#ИЗМЕНЕНИЕ /etc/profile
	cp ./profile /etc/profile
		
	if ! (ls /usr/lib/locale | grep -aq cp1251); then
		cp -r ./ru_RU.cp1251/ /usr/lib/locale/
		localedef -c -i ru_RU -f CP1251 ru_RU.CP1251
	else echo "Локаль CP1251 уже установлена"
	fi
	echo "Переключение локали на cp1251"
	export LANG=ru_RU.cp1251
}

install_from_repo (){

start_inst (){
for i in "$@"
do
  echo "Установка пакета `echo $i`"
  yum -y -q install $i
  rpm -q $i
  if [ $? -eq 0 ]; then
    tput setaf 2
    echo "Пакет `echo $i` установлен"
	tput sgr0
  else
    tput setaf 1
    echo "ОШИБКА!!! Пакет `echo $i` не установлен"
    tput sgr0
  fi
done
}

#Create local repository
echo "Подготовка локального репозитория"
mkdir -p /usr/share/repository
tar -xf local_repo.tar.gz -C /usr/share/repository
mkdir /etc/yum.repos.d/backup
mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup
cp /usr/share/repository/local.repo /etc/yum.repos.d/local.repo
yum clean all
#Проверка доступности локального репозитория
if ! (yum repolist | grep -aq "local_Repository"); then
  echo "ЛОКАЛЬНЫЙ РЕПОЗИТОРИЙ НЕДОСТУПЕН"
  echo "Ошибка настроек локального репозитория"
  exit 0
else 

echo "УСТАНОВКА ПАКЕТОВ ИЗ ЛОКАЛЬНОГО РЕПОЗИТОРИЯ"
start_inst net-tools
start_inst mc
start_inst nano
start_inst gdb
start_inst kernel-devel kernel-headers
start_inst htop atop iftop
start_inst glibc glibc-devel glibc-static libstdc++ libstdc++-devel compat-libstdc++-33 libstdc++-static
start_inst cmake make gcc-c++
start_inst cifs-utils
start_inst lshw pciutils

echo "Установка пакетов libpcap-1.8.1 и tcpdump-4.8.1" ## добавить проверки
mkdir -p /tmp/vrem_install
tar -xf libpcap-1.8.1.tar.gz -C /tmp/vrem_install
cd /tmp/vrem_install/libpcap-1.8.1
./configure
make install
cd $SCRIPTPWD
tar -xf tcpdump-4.8.1.tar.gz -C /tmp/vrem_install
cd /tmp/vrem_install/tcpdump-4.8.1
./configure
make install

tput setaf 2
echo "Установка дополнительного ПО завершена"
tput sgr0
fi

echo "Восстановление интернет репозиториев"
mv /etc/yum.repos.d/backup/*.repo /etc/yum.repos.d/
}

#########################################################################
############################ИСПОЛНЯЕМАЯ ЧАСТЬ############################
#########################################################################

echo "Скрипт подготовки сервера к инсталяции IP-ATC"

#####Установка Дополнительного ПО#####
echo -n "Начать установку дополнительного ПО? (y/n) "

read item
case "$item" in
    y|Y) echo "Ввели «y», установка ПО начата..."
		install_from_repo
		;;
    n|N) tput setaf 1
		echo "Ввели «n». Установка доп ПО отменена!"
		tput sgr0
        ;;
esac

#####Настройка интерфейсов#####

confeth

#####Установка драйверов сетевых плат Intel I210#####

echo -n "Начать установку дополнительного драйверов для сетевых плат Intel I210? (y/n) "

read item
case "$item" in
    y|Y) echo "Ввели «y», установка драйвера начата..."
		if ! (lshw -c network | grep '5.3.5.4' ); then
			echo 'Распаковка архива с драйвером...'
			cd $SCRIPTPWD
			tar -xf igb-5.3.5.4.tar.gz -C /tmp/intel/
			echo 'Подготовка конфигурационных файлов...'
			cd /etc/modprobe.d/
			touch modprobe.conf
			echo 'alias eno1 igb' >> modprobe.conf
			echo 'alias eno2 igb' >> modprobe.conf
			echo 'options igb RSS=1,1,1' >> modprobe.conf
			echo 'Установка и настройка драйвера...'
			cd /tmp/intel/
			rmmod igb   #отключение сети
			make uninstall
			make clean
			make install
			modprobe igb RSS=1,1,1
			if ! (lshw -c network | grep '5.3.5.4' ); then
				tput setaf 1
				echo "ОШИБКА!!! Новый драйвер не установлен!"
				tput sgr0
			else 
				tput setaf 2
				echo 'Установка драйвера для сетевых плат Intel I210 успешно завершена.'
				tput sgr0
			fi
		else echo 'Актуальный драйвер уже установлен.'
		fi
		;;
    n|N) tput setaf 1
		echo "Ввели «n». Установка драйверов отменена!"
		tput sgr0
        ;;
esac

#####Настройка локали#####

echo -n "Установить русскую локаль cp1251? (y/n) "

read item
case "$item" in
    y|Y) echo "Ввели «y», продолжаем..."
		if ! (locale | grep -aq cp1251); then
			echo "Настройка русской локали cp1251"
			conflocale;
			tput setaf 2
			echo "Russian locale cp1251 is successfully installed."
			tput sgr0
		else 
			tput setaf 1
			echo "ERROR"
			tput sgr0
			echo
		fi
		;;
    n|N) tput setaf 1
		echo "Ввели «n». Установка русской локали cp1251 отменена!"
		tput sgr0
        ;;
esac

#####Возвращаем копирование с подтверждением#####
alias cp="cp -i"

echo
tput setaf 2
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "++++++++++++++++++УСТАНОВКА ЗАВЕРШЕНА+++++++++++++++++"
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo 
echo "==Система будет готова к установке ПО IP-ATC после перезагрузки сервера=="
tput sgr0
echo

#####Перезапуск сервера#####
echo -n "Перезапустить сервер? (y/n) "

read item
case "$item" in
    y|Y) tput setaf 1
		echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++"
		echo "++СЕРВЕР АВТОМАТИЧЕСКИ ПЕРЕЗАПУСТИТСЯ ЧЕРЕЗ 1 МИНУТУ++"
		echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++"
		tput sgr0
		shutdown -r +1
		;;
    n|N) tput setaf 1
		echo "Ввели «n». Перезапуск отменен!"
		tput sgr0
        ;;
esac

exit 0
