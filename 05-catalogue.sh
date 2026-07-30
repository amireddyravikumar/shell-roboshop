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
dnf module disable nodejs -y &>>$LOG_FILE
dnf module enable nodejs:20 -y &>>$LOG_FILE
dnf install nodejs -y &>>$LOG_FILE
VALIDATE $? "Installing NodeJS:20"

id roboshop &>>$LOG_FILE
if [ $? -ne 0 ]; then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop  &>>$LOG_FILE
    VALIDATE $? "Creating roboshop system user"
else 
    echo -e "System user roboshop already created.. $Y SKIPPING $N" 
fi

rm -rf /app
VALIDATE $? "Removing existing code"

rm -rf /tmp/catalogue.zip
VALIDATE $? "Removed catalogue zip"

mkdir -p /app  &>>$LOG_FILE
VALIDATE $? "Creating app directory"

curl -o /tmp/catalogue.zip https://roboshop-artifacts.s3.amazonaws.com/catalogue-v3.zip &>>$LOG_FILE
cd /app 
unzip /tmp/catalogue.zip &>>$LOG_FILE
VALIDATE $? "Downloaded and extracted catalogue code"

npm install &>>$LOG_FILE
VALIDATE $? "Install dependencies"

cp $SCRIPT_DIR/catalogue.service /etc/systemd/system/catalogue.service
VALIDATE $? "created systemctl service"

cp $SCRIPT_DIR/mongo.repo /etc/yum.repos.d/mongo.repo
VALIDATE $? "Added Mongo repo" 

dnf install mongodb-mongosh -y &>>$LOG_FILE
VALIDATE $? "Installed mongodb client" 

INDEX=$(mongosh --host mongodb.amireddyravi.space --eval 'db.getMongo().getDBNames().indexOf("catalogue")')
if [ $INDEX -lt 0 ]; then
    mongosh --host mongodb.amireddyravi.space </app/db/master-data.js &>>$LOG_FILE
    VALIDATE $? "Load Products"
else 
    echo -e "Products already loaded ... $Y SKIPPING $N"
fi

systemctl enable catalogue &>>$LOG_FILE
systemctl restart catalogue &>>$LOG_FILE
VALIDATE $? "Restarting catalogue"