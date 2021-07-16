# Select the base image
FROM ubuntu:18.04

ARG NAME
ARG LINK_TOKEN

# Set all variables that affect programs to follow the same encoding
ENV LANG=C.UTF-8 LANGUAGE=C.UTF-8 LC_ALL=C.UTF-8

# Install here all the software your process needs in order to execute
RUN apt-get update --fix-missing && \
    apt-get install -y wget nano unzip bzip2 ca-certificates curl bash build-essential && \
    apt-get install -y fonts-indic fonts-noto fonts-noto-cjk && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* \

#install google chrome latest version
    && wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list \
    && apt-get -yqq update \
    && apt-get -yqq install google-chrome-stable \
    && rm -rf /var/lib/apt/lists/* \
    && chmod a+x /usr/bin/google-chrome \

#install chromedriver based on the chrome-version (compatible chromedriver and chrome has same main version number)
    && CHROME_VERSION=$(google-chrome --version) \
    && MAIN_VERSION=${CHROME_VERSION#Google Chrome } && MAIN_VERSION=${MAIN_VERSION%%.*} \
    && echo "main version: $MAIN_VERSION" \
    && CHROMEDRIVER_VERSION=`curl -sS chromedriver.storage.googleapis.com/LATEST_RELEASE_$MAIN_VERSION` \
    && echo "**********************************************************" \
    && echo "chrome version: $CHROME_VERSION" \
    && echo "chromedriver version: $CHROMEDRIVER_VERSION" \
    && echo "**********************************************************" \
    && mkdir -p /opt/chromedriver-$CHROMEDRIVER_VERSION \
    && echo "directory for chromedriver set: /opt/chromedriver-$CHROMEDRIVER_VERSION" \
    && curl -sS -o /tmp/chromedriver_linux64.zip http://chromedriver.storage.googleapis.com/$CHROMEDRIVER_VERSION/chromedriver_linux64.zip \
    && unzip -qq /tmp/chromedriver_linux64.zip -d /opt/chromedriver-$CHROMEDRIVER_VERSION  \
    && rm /tmp/chromedriver_linux64.zip \
    && echo "chromedriver copied to directory" \
    && chmod +x /opt/chromedriver-$CHROMEDRIVER_VERSION/chromedriver \
    && echo "original file: /opt/chromedriver-$CHROMEDRIVER_VERSION/chromedriver" \
    && echo "linked to file: /usr/local/bin/chromedriver" \
    && ln -fs /opt/chromedriver-$CHROMEDRIVER_VERSION/chromedriver /usr/local/bin/chromedriver

# Running as non-sudo user 'worker'
RUN useradd --no-log-init --system --create-home --shell /bin/bash worker
USER worker
WORKDIR /home/worker

# # Create the agent inside the image
# # Note 2021-03-15: Improvements coming to the loading of worker -> rcc -> micromamba to enclose these to some init commands.
# RUN mkdir -p /home/worker/bin && mkdir -p /home/worker/instance
# RUN curl --silent --show-error --fail -o /home/worker/bin/robocloud-worker https://downloads.cloud.robocorp.com/runtime/latest/linux64/robocloud-worker
# RUN chmod +x /home/worker/bin/robocloud-worker

# Create rcc inside the image
# When creating images one should always use specific versions to avoid unwanted changes, but also maintain the versions up-to-date.
# RCC change log at: https://github.com/robocorp/rcc/blob/master/docs/changelog.md
RUN mkdir -p /home/worker/bin/rcc/linux64
RUN curl --silent --show-error --fail -o /home/worker/bin/rcc/linux64/rcc https://downloads.robocorp.com/rcc/releases/v9.5.2/linux64/rcc
RUN chmod +x /home/worker/bin/rcc/linux64/rcc

# Add Micromamba for RCC
# RCC requires a specific version of Micromamba and will download it as needed
# This step just avoids the download.
RUN mkdir -p /home/worker/.robocorp/bin
RUN curl --silent --show-error --fail -o /home/worker/.robocorp/bin/micromamba https://downloads.robocorp.com/micromamba/v0.7.14/linux64/micromamba
RUN chmod +x /home/worker/.robocorp/bin/micromamba
ENV PATH /home/worker/.robocorp/bin:$PATH

RUN mkdir -p /home/worker/robots
WORKDIR /home/worker/robots
# COPY . /home/worker/robots

# Setup the run environment(s)
# Here you can give conda.yaml instructions to pre setup any kind of environment
# that will be run in the container
RUN /home/worker/bin/rcc/linux64/rcc env conda.yaml

# Link the App to Robocorp Cloud
# RUN /home/worker/bin/robocloud-worker link "$LINK_TOKEN" --name "$NAME" --instance-path /home/worker/instance

# ENTRYPOINT [ "/home/worker/bin/robocloud-worker", "start", "--instance-path", "/home/worker/instance" ]
# RUN /home/worker/bin/rcc/linux64/rcc run -e devdata/env.json

# ***** DOCKER RUN *****
# docker run -it -v "$(pwd)":/home/worker/robots thanhtdvn/robocorprunner bash
# /home/worker/bin/rcc/linux64/rcc run -e devdata/env.json
# mv output "output_$(date +"%Y-%m-%d %H-%M-%S")"

# ?! rcc pull
# ?? how to set output directory at runtime from rcc command + rcc env.json
# read bookmarked article about how to run rpa with docker jenkin
