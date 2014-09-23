FROM quay.io/aptible/ubuntu:14.04

RUN apt-get update

# Taken from dockerfile/java:oracle-java7
# Accept Oracle license agreement
RUN echo "oracle-java7-installer shared/accepted-oracle-license-v1-1 " \
         "select true" | debconf-set-selections
# Install Java 7 and clean up
RUN apt-get -y install software-properties-common && \
    add-apt-repository -y ppa:webupd8team/java && \
    apt-get update && apt-get install -y oracle-java7-installer && \
    rm -rf /var/lib/apt/lists/*

# Install Elasticsearch and clean up
RUN apt-get -y install wget && cd /tmp && \
    wget http://bit.ly/elasticsearch-132 && tar xvzf elasticsearch-132 && \
    mv /tmp/elasticsearch-1.3.2 /elasticsearch && rm -rf elasticsearch-132

# Mount elasticsearch.yml config
ADD templates/config/elasticsearch.yml /elasticsearch/config/elasticsearch.yml

# Integration tests
ADD test /tmp/test
RUN bats /tmp/test

VOLUME ["/data"]

# Expose HTTP port only
EXPOSE 9200

CMD ["/elasticsearch/bin/elasticsearch"]
