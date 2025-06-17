#!/bin/sh

# Default script behavior.
set -o errexit
#set -o pipefail

# Default parameters.
DEBUG=false
DEBUG_OPT=

# For each argument.
while :; do
	case ${1} in
		
		# If debuf is enabled.
		--debug)
			DEBUG=true
			DEBUG_OPT="--debug"
			;;

		# No more options.
		*)
			break

	esac 
	shift
done

# Using unavaialble variables should fail the script.
set -o nounset

# Enables interruption signal handling.
trap - INT TERM

# Print arguments if on debug mode.
${DEBUG} && echo "Running 'jenkins_configure'"

# If there is a git user.
if env | grep "GIT_USER_NAME=" && [ ! -z "${GIT_USER_NAME}" ]
then
	# Configures git.
	git config --global user.name ${GIT_USER_NAME}
fi

# If there is a git user.
if env | grep "GIT_USER_EMAIL=" && [ ! -z "${GIT_USER_EMAIL}" ]
then
	# Configures git.
	git config --global user.email ${GIT_USER_EMAIL}
fi

# If there is maven information.
if env | grep "MAVEN_REPOSITORY_ID=" && [ ! -z "${MAVEN_REPOSITORY_ID}" ]
then
	
	# Configures Maven.
	${DEBUG} && echo "Configuring Maven in continuous integration"
	tee .m2/settings.xml <<EOF
<settings>
	<servers>
		<server>
			<id>${MAVEN_REPOSITORY_ID}</id>
			<username>${MAVEN_USER_NAME}</username>
			<password>${MAVEN_USER_PASSWORD}</password>
		</server> 
	</servers> 
	<mirrors>
		<mirror>
			<id>${MAVEN_REPOSITORY_ID}</id>
			<name>Repository mirror</name>
			<url>${MAVEN_REPOSITORY_URL}</url>
			<mirrorOf>*</mirrorOf>
		</mirror>
	</mirrors>
	<profiles>
		<profile>
			<id>${MAVEN_REPOSITORY_ID}</id>
			<repositories>
				<repository>
				<id>${MAVEN_REPOSITORY_ID}</id>
				<url>${MAVEN_REPOSITORY_URL}</url>
					<releases><enabled>true</enabled></releases>
					<snapshots><enabled>true</enabled></snapshots>
				</repository>
			</repositories>
			<pluginRepositories>
				<pluginRepository>
				<id>${MAVEN_REPOSITORY_ID}</id>
				<url>${MAVEN_REPOSITORY_URL}</url>
					<releases><enabled>true</enabled></releases>
					<snapshots><enabled>true</enabled></snapshots>
				</pluginRepository>
			</pluginRepositories>
		</profile>
	</profiles>
	<activeProfiles>
		<activeProfile>${MAVEN_REPOSITORY_ID}</activeProfile>
	</activeProfiles>
</settings>
EOF

fi


# If there is PyPi information.
if env | grep "PYPI_REPOSITORY_ID=" && [ ! -z "${PYPI_REPOSITORY_ID}" ]
then
	
	# Configures PyPi.
	${DEBUG} && echo "Configuring PyPi in continuous integration"
	tee .pypirc <<EOF
	
[distutils]
index-servers =
    ${PYPI_REPOSITORY_ID}
    ${PYPI_RELEASES_REPOSITORY_ID}
    ${PYPI_SNAPSHOTS_REPOSITORY_ID}

[${PYPI_REPOSITORY_ID}]
repository = http://${PYPI_REPOSITORY_URL}
username = ${PYPI_USER_NAME}
password = ${PYPI_USER_PASSWORD}

[${PYPI_RELEASES_REPOSITORY_ID}]
repository = http://${PYPI_RELEASES_REPOSITORY_URL}
username = ${PYPI_USER_NAME}
password = ${PYPI_USER_PASSWORD}

[${PYPI_SNAPSHOTS_REPOSITORY_ID}]
repository = http://${PYPI_SNAPSHOTS_REPOSITORY_URL}
username = ${PYPI_USER_NAME}
password = ${PYPI_USER_PASSWORD}

EOF

	mkdir -p .pyp
	tee .pyp/pip.conf <<EOF
	
[global]
index = http://${PYPI_USER_NAME}:${PYPI_USER_PASSWORD}@${PYPI_REPOSITORY_URL}/pypi
index-url = http://${PYPI_USER_NAME}:${PYPI_USER_PASSWORD}@${PYPI_REPOSITORY_URL}/simple

EOF

fi


# If there is public Docker information.
if env | grep "DOCKER_PUBLIC_USER_NAME=" && [ ! -z "${DOCKER_PUBLIC_USER_NAME}" ]
then

	# Logs in the Docker repository.
	${DEBUG} && echo "Logging in the docker repository"
	docker login -u ${DOCKER_PUBLIC_USER_NAME} \
		-p ${DOCKER_PUBLIC_USER_PASSWORD} || \
	echo "Docker login failed."

fi

# If there is private Docker information.
if env | grep "DOCKER_PRIVATE_USER_NAME=" && [ ! -z "${DOCKER_PRIVATE_USER_NAME}" ]
then

	# Logs in the Docker repository.
	${DEBUG} && echo "Logging in the docker repository"
	docker login -u ${DOCKER_PRIVATE_USER_NAME} \
		-p ${DOCKER_PRIVATE_USER_PASSWORD} ${DOCKER_PRIVATE_REPOSITORY_URL} || \
	echo "Docker login failed."

	${DEBUG} && echo "Logging in the docker s3 repository"
	docker login -u ${DOCKER_PRIVATE_USER_NAME} \
		-p ${DOCKER_PRIVATE_USER_PASSWORD} ${DOCKER_PRIVATE_S3_REPOSITORY_URL} || \
	echo "Docker login S3 failed."

fi

# If there is DCOs configuration.
if [ -d ${JENKINS_HOME}/dcos/ ]
then

	# For each configured enviroment.
	for CURRENT_ENVIRONMENT in ${HOME}/dcos/*
	do
	
		${DEBUG} && echo "Running DCOS CLI for ${CURRENT_ENVIRONMENT}"
		. ${CURRENT_ENVIRONMENT}/dcos_cli.properties
		export CLUSTER_ADDRESS
		export DCOS_DIR=${CURRENT_ENVIRONMENT}
		dcos_init \
			--uid continuous-integration \
			--private-key ${HOME}/secrets/continuous_integration_private.pem || \
		echo "DCOS CLI not available for ${CURRENT_ENVIRONMENT}."
	
	done

fi


