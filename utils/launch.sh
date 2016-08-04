#! /bin/bash

MACH_PREFIX=$1
DATACENTERS=$2
START_N=$3
END_N=$4
REGION=$5

if [[ "$CLOUD_PROVIDER" == "" ]]; then
	CLOUD_PROVIDER="amazonec2"
fi

echo "" 
echo "Launch!"
echo "Machine prefix: $MACH_PREFIX"
echo "Datacenters: $DATACENTERS"
echo "Cloud: $CLOUD_PROVIDER"
echo "Start node num: $START_N"
echo "End node num: $END_N"
echo ""

if [[ "$AWS_INSTANCE_TYPE" == "" ]]; then
	AWS_INSTANCE_TYPE="t2.medium"
fi

if [[ "$DATACENTERS" == "single" ]]; then
	case "$CLOUD_PROVIDER" in 
		"digitalocean")
			# expects DIGITALOCEAN_ACCESS_TOKEN to be set
			mintnet create --machines "${MACH_PREFIX}[${START_N}-${END_N}]" -- --driver=digitalocean --digitalocean-image docker
			;;
		"amazonec2")
			mintnet create --machines "${MACH_PREFIX}[${START_N}-${END_N}]" -- --driver=amazonec2 --amazonec2-access-key=$AWS_ACCESS_KEY --amazonec2-secret-key=$AWS_SECRET_KEY --amazonec2-security-group=$AWS_SECURITY_GROUP --amazonec2-instance-type=$AWS_INSTANCE_TYPE
			mintnet docker --machines "${MACH_PREFIX}[${START_N}-${END_N}]"  -- \; sudo usermod -aG docker ubuntu
	 		;;
		*)
			echo "CLOUD_PROVIDER must be amazonec2 or digitalocean"
			exit 1
	esac

elif [[ "$DATACENTERS" == "multi" ]]; then
	go run utils/create.go $CLOUD_PROVIDER $MACH_PREFIX $START_N $END_N
else
	echo "DATACENTERS argument must be 'single' or 'multi'. Got $DATACENTERS"
	exit 1
fi
