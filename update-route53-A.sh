#!/bin/sh
################################################################################
# Name:        update-route53-A.sh                                             #
# Description: Update Route 53 with an instance's (dynamic) public IP address. #
# Author:      Robin Venables                                                  #
# Date:        21 December 2017                                                #
################################################################################
# Update History:                                                              #
# Date        Author          Notes                                            #
# ==========  ==============  ================================================ #
# 21/12/2017  Robin Venables  Initial version                                  #
################################################################################

JSON="/home/ec2-user/bin/update-route53-A.json"
TTL=60

/bin/echo -n "Getting instance ID... "
INSTANCE_ID=$(curl --silent http://169.254.169.254/latest/meta-data/instance-id)
echo ${INSTANCE_ID}

/bin/echo -n "Getting availability zone... "
AVAILABILITY_ZONE=$(curl --silent http://169.254.169.254/latest/meta-data/placement/availability-zone)
echo ${AVAILABILITY_ZONE}

/bin/echo -n "Getting FQDN... "
FQDN=$(aws ec2 describe-instances --instance-ids "${INSTANCE_ID}" --query "Reservations[*].Instances[*].[Tags[?Key=='FQDN'].Value]" --output text --region=${AVAILABILITY_ZONE%?})
echo ${FQDN}

/bin/echo -n "Getting IP... "
if [ -z "$1" ]; then 
    PUBLIC_IP=$(curl --silent http://169.254.169.254/latest/meta-data/public-ipv4)  
else 
    PUBLIC_IP="$1" 
fi
echo ${PUBLIC_IP}

/bin/echo -n "Getting hosted zone ID... "
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name | grep -B 1 -e "${FQDN%.*}" | sed 's/.*hostedzone\/\([A-Za-z0-9]*\)\".*/\1/' | head -n 1)
echo ${HOSTED_ZONE_ID}

cat <<EOF > ${JSON}
{
  "Comment": "Update the A record set for this instance",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${FQDN}",
        "Type": "A",
        "TTL": ${TTL},
        "ResourceRecords": [
          {
            "Value": "${PUBLIC_IP}"
          }
        ]
      }
    }
  ]
}
EOF

/bin/echo "Updating DNS... "
aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --change-batch file://${JSON}
