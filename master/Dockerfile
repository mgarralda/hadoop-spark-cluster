# Get base image
FROM hadoop_spark_base_image:latest

# Switch to root to perform system-level tasks
USER root

# Ensure the run script is copied and has execution permission
COPY ./scripts/run_master.sh /home/sparker/run.sh
RUN chmod +x /home/sparker/run.sh

# Set sudo access for sparker (already in base, but kept for clarity)
RUN echo "sparker ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Optional: ensure SSH server is enabled at runtime (handled in run.sh ideally)
RUN mkdir -p /var/run/sshd

# Copy Hadoop and Spark configuration files
COPY ./conf-master/core-site.xml /home/sparker/hadoop-$HADOOP_VERSION/etc/hadoop/
COPY ./conf-master/yarn-site.xml /home/sparker/hadoop-$HADOOP_VERSION/etc/hadoop/
COPY ./conf-master/mapred-site.xml /home/sparker/hadoop-$HADOOP_VERSION/etc/hadoop/
COPY ./conf-master/hdfs-site.xml /home/sparker/hadoop-$HADOOP_VERSION/etc/hadoop/
COPY ./conf-master/spark-defaults.conf /home/sparker/spark-$SPARK_VERSION-bin-hadoop3/conf/

# Switch back to user sparker
USER sparker
WORKDIR /home/sparker

# Format HDFS only in the master (not needed in slaves)
RUN $HADOOP_HOME/bin/hdfs namenode -format

# Entrypoint to launch SSH and Spark services
ENTRYPOINT ["./run.sh"]
