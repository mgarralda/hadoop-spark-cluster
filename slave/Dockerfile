# Get base image
FROM hadoop_spark_base_image:latest

# Switch to root to perform system-level tasks
USER root

# Copy and prepare the slave start script
COPY ./scripts/run_slave.sh /home/sparker/run.sh
RUN chmod +x /home/sparker/run.sh

# Confirm sparker has sudo privileges
RUN echo "sparker ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Optional: ensure SSH server is enabled at runtime (handled in run.sh ideally)
RUN mkdir -p /var/run/sshd

# Copy Hadoop configuration files
COPY ./conf-slave/core-site.xml /home/sparker/hadoop-$HADOOP_VERSION/etc/hadoop/
COPY ./conf-slave/yarn-site.xml /home/sparker/hadoop-$HADOOP_VERSION/etc/hadoop/
COPY ./conf-slave/mapred-site.xml /home/sparker/hadoop-$HADOOP_VERSION/etc/hadoop/
COPY ./conf-slave/hdfs-site.xml /home/sparker/hadoop-$HADOOP_VERSION/etc/hadoop/

# Switch back to user sparker
USER sparker
WORKDIR /home/sparker

# Entrypoint to launch SSH and Spark services
ENTRYPOINT ["./run.sh"]
