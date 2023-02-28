#!/bin/sh
echo "Available instances:"
# List instances were Name tag is set to "GPU" and product tag is set to "gpu-streaming"
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name]'\
    --filter Name=tag:product,Values=gpu-streaming --output text

# Enter option by number
echo "1 - Launch GPU instance"
echo "2 - Terminate GPU instance"
echo "3 - Terminate ALL instances"
echo "4 - Refresh"
echo "5 - Exit"

read -p "Enter option: " option

case $option in
    1)
        # start storagegateway instance if not running
        if [ -z "$(aws ec2 describe-instances --query 'Reservations[*].Instances[?Tags[?Key==`Name`].Value|[0]==`storagegateway`].[InstanceId]' --filter 'Name=tag:product,Values=gpu-streaming' 'Name=instance-state-name,Values=running' --output text)" ]; then
            echo "Starting storagegateway instance..."
            storagegateway_id=$(aws ec2 run-instances --launch-template LaunchTemplateName=storage-gateway --query 'Instances[*].[InstanceId]' --output text)
            echo $storagegateway_id
            # wait for storagegateway instance to be running
            while [ -z "$(aws ec2 describe-instances --query 'Reservations[*].Instances[?Tags[?Key==`Name`].Value|[0]==`storagegateway`].[InstanceId]' --filter 'Name=tag:product,Values=gpu-streaming' 'Name=instance-state-name,Values=running' --output text)" ]; do
                echo "Waiting for storagegateway instance to be running..."
                sleep 5
            done
            # attach cache ebs volume to storagegateway instance
            aws ec2 attach-volume --volume-id vol-020cdef7aaaaa4743 --device /dev/sdb --instance-id $storagegateway_id --region eu-west-1
        fi

        # Launch GPU instance
        echo "Launching GPU instance..."
        # generate random string for instance name
        random_string=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
        # ask for instance name, default to random string
        read -p "Enter instance name (default: $random_string): " instance_name
        instance_name=${instance_name:-$random_string}
        # ask for instance type, default to g4dn.xlarge
        read -p "Enter instance type (default: g4dn.xlarge): " instance_type
        instance_type=${instance_type:-g4dn.xlarge}

        # launch instance from template by name GPU
        gpu_id=$(aws ec2 run-instances --launch-template LaunchTemplateName=GPU --instance-type ${instance_type} --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance_name}]" --query 'Instances[*].[InstanceId]' --output text)
        echo $gpu_id

        # wait for instance with name in instance_name to be running
        while [ -z "$(aws ec2 describe-instances --instance-ids $gpu_id)" ]; do
            echo "Waiting for instance to be running..."
            sleep 5
        done
        ;;


    2)
        # Terminate instance
        echo "Terminating instance..."
        read -p "Enter instance ID: " instance_id
        aws ec2 terminate-instances --instance-ids $instance_id
        ;;
    3)
        # Terminate all instances
        echo "Terminating all instances..."
        aws ec2 terminate-instances --instance-ids $(aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId]' --filter Name=tag:product,Values=gpu-streaming --output text)
        ;;
    4)
        # Refresh
        echo "Refreshing..."
        ;;
    5)
        # Exit
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo "Invalid option"
        ;;
esac
# go back to start
sh start-server.sh

