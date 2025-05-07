#!/bin/sh

# Default script behavior.
set -o errexit
#set -o pipefail

# Default paramentes.
DEBUG=false
DEBUG_OPT=
WORK_DIRECTORY=.
USE_PRIVATE_IP=true
USE_SSH=false
SSH_ARGUMENTS=
EXTRA_ARGUMENTS=
COMMAND=
STD_IN=
STD_IN_TEMP_FILE=nomad_docker_exec_stdin.tmp

# For each parameter.
while :; do
	case ${1} in
		
		# If debug should be enabled.
		--debug)
			DEBUG=true
			DEBUG_OPT="--debug"
			;;

		# Job id.
		-j|--app-id)
			JOB_ID=${2}
			shift
			;;
		-t|--token)
			NOMAD_TOKEN=${2}
			shift
			;;
		-h|--host)
			HOST_NOMAD=${2}
			shift
			;;
			
		# If regular SSH should be used.
		--use-ssh)
			USE_SSH=true
			;;

		# SSH key.
		-k|--key)
			SSH_ARGUMENTS="${SSH_ARGUMENTS} --key ${2}"
			shift
			;;

		# Key checking desabled.
		--key-checking-disabled)
			SSH_ARGUMENTS="${SSH_ARGUMENTS} --key-checking-disabled"
			;;

		# If docker command should run as root.
		-r|--root)
			EXTRA_ARGUMENTS="${EXTRA_ARGUMENTS} -u root"
			;;
		
		# Extra arguments.
		-*)
			EXTRA_ARGUMENTS="${EXTRA_ARGUMENTS} ${1}"
			;;
			
		# Command.
		*)
			COMMAND="${@}"
			break

	esac 
	shift
done


# Initialize
AGENT_IP=
ALLOC_ID=
TASK_ID=

# Reads from stdin.
rm -f ${STD_IN_TEMP_FILE}
touch ${STD_IN_TEMP_FILE}
if [ ! -t 0 ]
then
	while read LINE
	do
		USE_SSH=true
		STD_IN="${STD_IN}${LINE}\n"
		echo "${LINE}" >> ${STD_IN_TEMP_FILE}
	done
fi

${DEBUG} && echo "STD_IN=$(cat ${STD_IN_TEMP_FILE})"

# Using unavaialble variables should fail the script.
set -o nounset

# Enables interruption signal handling.
trap - INT TERM

# Print parameters if on debug mode.
${DEBUG} && echo "Running 'nomad_docker_exec'"
${DEBUG} && echo "JOB_ID=${JOB_ID}"
${DEBUG} && echo "SSH_ARGUMENTS=${SSH_ARGUMENTS}"
${DEBUG} && echo "EXTRA_ARGUMENTS=${EXTRA_ARGUMENTS}"
${DEBUG} && echo "COMMAND=${COMMAND}"
${DEBUG} && echo "HOST_NOMAD=${HOST_NOMAD}"

# Get allocation
ALLOC_ID=$(curl -sk \
	--header "X-Nomad-Token: ${NOMAD_TOKEN}" \
  	${HOST_NOMAD}/v1/job/${JOB_ID}/allocations \
	| jq -r '[.[] | select(.ClientStatus == "running")][0].ID') 

# Get host ip
AGENT_IP=$(curl -sk \
	--header "X-Nomad-Token: ${NOMAD_TOKEN}" \
  	${HOST_NOMAD}/v1/allocation/${ALLOC_ID} \
	| jq -r '.AllocatedResources.Shared.Ports[0].HostIP')

# Mount docker name to exec
TASK_ID="${JOB_ID}-${ALLOC_ID}"

${DEBUG} && echo "ALLOC_ID=${ALLOC_ID}"
${DEBUG} && echo "TASK_ID=${TASK_ID}"
${DEBUG} && echo "AGENT_IP=${AGENT_IP}"

# If there is no stdin.
if [ -z "${STD_IN}" ]
then 

	${DEBUG} && echo "Running 'nomad_ssh ${DEBUG_OPT} ${SSH_ARGUMENTS} --ip ${AGENT_IP} \
		sudo docker exec ${EXTRA_ARGUMENTS} ${TASK_ID} \"${COMMAND}\"'"

	nomad_ssh ${DEBUG_OPT} ${SSH_ARGUMENTS} --ip ${AGENT_IP} \
		sudo docker exec ${EXTRA_ARGUMENTS} ${TASK_ID} ${COMMAND}

# If there is stdin.
else 
	${DEBUG} && echo "Running 'nomad_ssh ${DEBUG_OPT} ${SSH_ARGUMENTS} --ip ${AGENT_IP} \
		sudo docker exec ${EXTRA_ARGUMENTS} ${TASK_ID} \"${COMMAND}\" < ${STD_IN_TEMP_FILE}'"
		
	nomad_ssh ${DEBUG_OPT} ${SSH_ARGUMENTS} --ip ${AGENT_IP} \
		sudo docker exec ${EXTRA_ARGUMENTS} ${TASK_ID} ${COMMAND} < ${STD_IN_TEMP_FILE}

fi
