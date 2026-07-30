#!/bin/bash

LOGS_FOLDER="/var/log/roboshop"
sudo mkdir -p $LOGS_FOLDER
sudo chown -R ec2-user:ec2-user $LOGS_FOLDER
sudo chmod -R 755 $LOGS_FOLDER
LOG_FILE="$LOGS_FOLDER/$0.log"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

USERID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

if [ $USERID -ne 0 ]; then
    echo -e "$R Please run with root access $N" | tee -a $LOG_FILE
    exit 1
fi
function VALIDATE(){
    if [ $1 -ne 0 ]; then
        echo -e "$TIMESTAMP [ERROR] $2...  $R FAILED $N" | tee -a $LOG_FILE
        exit 1
    else 
        echo -e "$TIMESTAMP [INFO] $2... $G SUCCESS $N" | tee -a $LOG_FILE
    fi
}
dnf module disable redis -y &>> $LOG_FILE
dnf module enable redis:7 -y &>> $LOG_FILE
dnf install redis -y &>> $LOG_FILE
VALIDATE $? "Installing Redis"

sed -i -e 's/127.0.0.1/0.0.0.0/g' -e '/protected-mode/ c protected-mode no' /etc/redis/redis.conf
VALIDATE $? "Allowing remote connection to Redis"

systemctl enable --now redis &>> $LOG_FILE
VALIDATE $? "starting and enabling Redis"