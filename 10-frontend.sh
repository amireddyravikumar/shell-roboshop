#!/bin/bash

LOGS_FOLDER="/var/log/roboshop"
sudo mkdir -p $LOGS_FOLDER
sudo chown -R ec2-user:ec2-user $LOGS_FOLDER
sudo chmod -R 755 $LOGS_FOLDER
LOG_FILE="$LOGS_FOLDER/$0.log"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
SCRIPT_DIR=$PWD
MYSQL_HOST=mysql.amireddyravi.space

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

dnf module disable nginx -y &>>$LOG_FILE
dnf module enable nginx:1.24 -y &>>$LOG_FILE
dnf install nginx -y &>>$LOG_FILE
VALIDATE $? "Installed nginx"

rm -rf /usr/share/nginx/html/* 
VALIDATE $? "Removing existing code"

curl -o /tmp/frontend.zip https://roboshop-artifacts.s3.amazonaws.com/frontend-v3.zip &>>$LOG_FILE 
cd /usr/share/nginx/html 
unzip /tmp/frontend.zip &>>$LOG_FILE 
VALIDATE $? "Downloaded and extracted fronend code"

rm -rf /etc/nginx/nginx.conf
cp $SCRIPT_DIR/nginx.conf /etc/nginx/nginx.conf
VALIDATE $? "COpied robosop nginx conf"
 

systemctl enable nginx &>>$LOG_FILE
systemctl restart nginx &>>$LOG_FILE
VALIDATE $? "ENabled and Restarted NGINX"