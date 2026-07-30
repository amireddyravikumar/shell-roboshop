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
ddnf install python3 gcc python3-devel -y &>>$LOG_FILE
VALIDATE $? "Installing python"

id roboshop &>>$LOG_FILE
if [ $? -ne 0 ]; then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop  &>>$LOG_FILE
    VALIDATE $? "Creating roboshop system user"
else 
    echo -e "System user roboshop already created.. $Y SKIPPING $N" 
fi

rm -rf /app
VALIDATE $? "Removing existing code"

rm -rf /tmp/payment.zip
VALIDATE $? "Removed payment zip"

mkdir -p /app  &>>$LOG_FILE
VALIDATE $? "Creating app directory"

curl -L -o /tmp/payment.zip https://roboshop-artifacts.s3.amazonaws.com/payment-v3.zip &>>$LOG_FILE 
cd /app 
unzip /tmp/payment.zip &>>$LOG_FILE
VALIDATE $? "Downloaded and extracted payment code"

pip3 install -r requirements.txt &>>$LOG_FILE
VALIDATE $? "Install dependencies"

cp $SCRIPT_DIR/payment.service /etc/systemd/system/payment.service
VALIDATE $? "created systemctl service"
 
systemctl enable payment &>>$LOG_FILE
systemctl restart payment &>>$LOG_FILE
VALIDATE $? "Enabled and Restarted payment"