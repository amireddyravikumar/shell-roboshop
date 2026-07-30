#!/bin/bash

LOGS_FOLDER="/var/log/roboshop"
sudo mkdir -p $LOGS_FOLDER
sudo chown -R ec2-user:ec2-user $LOGS_FOLDER
sudo chmod -R 755 $LOGS_FOLDER
LOG_FILE="$LOGS_FOLDER/$0.log"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
SCRIPT_DIR=$PWD

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
dnf install maven -y &>>$LOG_FILE
VALIDATE $? "Installing maven"

id roboshop &>>$LOG_FILE
if [ $? -ne 0 ]; then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop  &>>$LOG_FILE
    VALIDATE $? "Creating roboshop system user"
else 
    echo -e "System user roboshop already created.. $Y SKIPPING $N" 
fi

rm -rf /app
VALIDATE $? "Removing existing code"

rm -rf /tmp/shipping.zip
VALIDATE $? "Removed shipping zip"

mkdir -p /app  &>>$LOG_FILE
VALIDATE $? "Creating app directory"

curl -L -o /tmp/shipping.zip https://roboshop-artifacts.s3.amazonaws.com/shipping-v3.zip &>>$LOG_FILE 
cd /app 
unzip /tmp/shipping.zip &>>$LOG_FILE
VALIDATE $? "Downloaded and extracted shipping code"

mvn clean package &>>$LOG_FILE
VALIDATE $? "Install dependencies"
mv target/shipping-1.0.jar shipping.jar

cp $SCRIPT_DIR/shipping.service /etc/systemd/system/shipping.service
VALIDATE $? "created systemctl service"

dnf install mysql -y &>>$LOG_FILE
VALIDATE $? "created MySql Client"

# systemctl enable cart &>>$LOG_FILE
# systemctl restart cart &>>$LOG_FILE
# VALIDATE $? "Restarting cart"