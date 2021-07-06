# From service cluster CLI.
FROM coldis/infrastructure-service-cluster-cli AS service-cluster-cli

# From Jenkins.
FROM jenkins/jenkins:2.291-jdk11

# Sets the user to root.
USER root

# Changes locale and timezone.
ENV TZ=America/Sao_Paulo \
	LANG_FILE=pt_BR.UTF-8 \
	LANG=pt_BR.utf8 \
	LANGUAGE=pt_BR:pt \
	LC_ALL=pt_BR.UTF-8
RUN rm -f /usr/share/locale/locale.alias && \
	ln -s /etc/locale.alias /usr/share/locale/locale.alias && \
	localedef -i pt_BR -c -f UTF-8 -A /usr/share/locale/locale.alias ${LANG_FILE} && \
	cp /usr/share/zoneinfo/${TZ} /etc/localtime && \
	apt-get purge -y locales

# Installs basic tools and languages.
RUN apt-get update -y && \
	apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common && \
	apt-get remove -y docker docker.io && \
	curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add - && \
	add-apt-repository -y \
		"deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable" && \
	apt-get update -y && \
	apt-get install -y docker-ce docker-ce-cli && \
	usermod -aG docker jenkins && \
	systemctl enable docker && \
	apt-get install -y jq cron gosu zip unzip jq git && \
	apt-get install -y maven && \
	apt-get install -y python3 python3-pip && \
	pip3 install twine && \
	curl -sL https://deb.nodesource.com/setup_12.x | bash - && \	
	apt-get install -y nodejs && \
	npm cache clean -f && \
	npm install -g n && \
	apt-get autoremove -y && \
	apt-get clean -y && \
	rm -rf /var/lib/apt/lists/*
	
# Installs chrome driver.
RUN apt-get update -y && \
	apt-get install -y wget unzip && \
	mkdir -p temp/ && \
	cd temp && \
	wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
	( dpkg -i google-chrome-stable_current_amd64.deb || true ) && \
	apt-get install -yf && \
	LATEST_CHROMEDRIVER=$(curl https://chromedriver.storage.googleapis.com/LATEST_RELEASE) && \
	wget https://chromedriver.storage.googleapis.com/$LATEST_CHROMEDRIVER/chromedriver_linux64.zip && \
	mkdir -p /opt/chromedriver/ && \
	unzip chromedriver_linux64.zip -d /opt/chromedriver/ && \
	cd .. && \
	rm -rf temp/ && \
	apt-get remove -y unzip && \
	apt-get autoremove -y && \
	apt-get clean -y && \
	rm -rf /var/lib/apt/lists/*
	
# Installs service cluster CLI.
ENV DCOS_VERSION="latest"
COPY --from=service-cluster-cli /opt/dcos-script/ /opt/dcos-script/
RUN	chmod +x /opt/dcos-script/*.sh && \
	ln -s /opt/dcos-script/*.sh /usr/bin && \
	for FILE in /usr/bin/dcos*.sh; do  mv -- "${FILE}" "${FILE%.sh}"; done && \
	dcos_install --version ${DCOS_VERSION}
	
# Copies operational scripts.
COPY --from=service-cluster-cli /opt/operational-utils-script/ /opt/operational-utils-script/
RUN	chmod +x /opt/operational-utils-script/utils/script/*.sh && \
	ln -s /opt/operational-utils-script/utils/script/*.sh /usr/bin && \
	for FILE in /usr/bin/operational_utils*.sh; do  mv -- "${FILE}" "${FILE%.sh}"; done

# Copies scripts.
ENV JENKINS_SCRIPT=/opt/jenkins-script
RUN mkdir -p ${JENKINS_SCRIPT}
COPY script ${JENKINS_SCRIPT}
RUN chown -R jenkins:jenkins ${JENKINS_SCRIPT} && \
	ln -s ${JENKINS_SCRIPT}/*.sh /usr/bin && \
	for FILE in /usr/bin/jenkins*.sh; \
	do \
		chown jenkins:jenkins ${FILE} && \	
		mv -- "${FILE}" "${FILE%.sh}"; \
	done

# Add android cmd-line tool.
RUN apt-get update -y && \
	apt-get install -y wget unzip && \
	wget https://dl.google.com/android/repository/commandlinetools-linux-7302050_latest.zip && \
	mkdir -p /opt/android-sdk && \
    	unzip commandlinetools-linux-7302050_latest.zip -d /opt/android-sdk && \
	rm commandlinetools-linux-7302050_latest.zip && \
	mkdir /opt/tools && \
	mv /opt/android-sdk/cmdline-tools/* /opt/tools && \
	mv /opt/tools/ /opt/android-sdk/cmdline-tools/ && \
	yes | /opt/android-sdk/cmdline-tools/tools/bin/sdkmanager --licenses && \
	cd /opt/android-sdk/cmdline-tools/tools/bin/ && \
    	./sdkmanager "platforms;android-30" "build-tools;30.0.0" "build-tools;30.0.2" "extras;google;m2repository"

ENV ANDROID_HOME=/opt/android-sdk/

# Configures scheduled jobs.
#COPY cron /etc/cron.d
#RUN chmod -R 0644 /etc/cron.d/ && \
#	crontab /etc/cron.d/jenkins_jobs && \
#	touch /var/jenkins_home/cron_env && \
#	chown jenkins.jenkins /var/jenkins_home/cron_env && \
#	service cron start
	
# Sets the user back to Jenkins.
USER jenkins
ENV HOME=/var/jenkins_home
WORKDIR /var/jenkins_home

# Creates necessary directories.
RUN mkdir -p .m2 secrets

# Configures Java memory.
ENV JAVA_OPTS="-Xms128m -Xmx5g -XX:MaxDirectMemorySize=5g"
ENV MAVEN_OPTS="-Xms128m -Xmx5g -XX:MaxDirectMemorySize=5g"

# Installs plugins.
COPY config/plugins.conf /usr/share/jenkins/ref/plugins.conf
RUN /usr/local/bin/install-plugins.sh < /usr/share/jenkins/ref/plugins.conf

# Entrypoint.
ENTRYPOINT [ "jenkins_init" ]

