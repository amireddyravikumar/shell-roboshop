#!/bin/bash

AMI_ID="ami-0220d79f3f480ecf5"
ZONE_ID="Z02709521C0H67BW0WAUD"
DOMAIN_NAME="amireddyravi.space"
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"
echo "total args: $#"

if [ $# -lt 2 ]; then
    echo -e "%R ERROR.. Alleast 2 arguments required $N"
    echo "USAGE: $0 [create/delete] [instance1] [instance2] ..."
    exit 1
fi

ACTION=$1
shift

if [ "$ACTION" != "create" ] && [ "$ACTION" != "delete" ] ; then
    echo -e "$R ERROR..First argument must be either create or delete $N"
    echo "USAGE: $0 [create/delete] [instance1] [instance2] ..."
    exit 1
fi
get_instance_id (){
    name=$1
    aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=roboshop-$name" \
            "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query "Reservations[0].Instances[0].InstanceId" \
    --output text
    
}
for instance in $@
do
    echo "passing instance : $instance"
    INSTANCE_ID=$(get_instance_id $instance)
    echo "existing instance : $INSTANCE_ID"
    if [ $ACTION == "create" ]; then
        if [ $INSTANCE_ID == "None" ]; then
            INSTANCE_ID=$(aws ec2 run-instances \
                --image-id $AMI_ID \
                --instance-type t3.micro \
                --security-groups "roboshop-common" "roboshop-$instance" \
                --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value="roboshop-$instance"}]" \
                --query 'Instances[0].InstanceId' \
                --output text
            )
            echo "Newly launched instance: $INSTANCE_ID"            
        else 
            echo "roboshop-$instance alredy running: $INSTANCE_ID"
        fi
        # updated route 53 record
        if [ $instance = "frontend" ]; then
            IP=$(aws ec2 describe-instances \
                    --instance-ids $INSTANCE_ID \
                    --query "Reservations[0].Instances[0].PublicIpAddress" \
                    --output text
                )
                R53_RECORD="$DOMAIN_NAME"
            else 
                IP=$(aws ec2 describe-instances \
                    --instance-ids $INSTANCE_ID \
                    --query "Reservations[0].Instances[0].PrivateIpAddress" \
                    --output text
                )
                R53_RECORD="$instance.$DOMAIN_NAME"
            fi
            echo "IP: $IP"

            aws route53 change-resource-record-sets \
                    --hosted-zone-id $ZONE_ID \
                    --change-batch '
                        {
                            "Comment": "Update A Record with new IP",
                            "Changes": 
                            [{
                                "Action": "UPSERT",
                                "ResourceRecordSet": 
                                {
                                    "Name": "'$R53_RECORD'",
                                    "Type": "A",
                                    "TTL": 1,
                                    "ResourceRecords":
                                    [{
                                        "Value": "'$IP'"
                                    }]
                                }
                            }]
                        }
                    '
        echo "Route 53 record is updated for $instance"
    else 
        if [ $INSTANCE_ID == "None" ]; then
            echo "$instance is already deleted, nothing to do..."
        else 
            aws ec2 terminate-instances --instance-ids $INSTANCE_ID 
            echo "Terminating Instance: $instance"    
        fi
    fi        
done