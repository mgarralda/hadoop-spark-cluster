// =============================================================================
// Force JVM to use custom Log4j2 configuration
// =============================================================================
System.setProperty("log4j.configurationFile", "/usr/local/spark/conf/log4j2.properties")
System.setProperty("io.netty.tryReflectionSetAccessible", "true")

// Almond starts its JVM directly, so spark-submit does not load these defaults.
// Add Hadoop XML resources to the interpreter classpath for HDFS and YARN.
interp.load.cp(os.Path(sys.env("HADOOP_CONF_DIR")))
locally {
  val sparkDefaultsSource = scala.io.Source.fromFile(
    sys.env("SPARK_HOME") + "/conf/spark-defaults.conf"
  )
  try {
    sparkDefaultsSource.getLines().map(_.trim)
      .filter(line => line.nonEmpty && !line.startsWith("#"))
      .foreach { line =>
        val entry = line.split("\\s+", 2)
        require(entry.length == 2 && entry(0).startsWith("spark."),
          "Invalid Spark default: " + line)
        if (System.getProperty(entry(0)) == null)
          System.setProperty(entry(0), entry(1))
      }
  } finally {
    sparkDefaultsSource.close()
  }
}

// =============================================================================
// Spark Core + ML Libraries
// =============================================================================
import $ivy.`org.apache.spark::spark-sql:3.5.9`
import $ivy.`org.apache.spark::spark-mllib:3.5.9`
import $ivy.`org.apache.spark::spark-graphx:3.5.9`

// =============================================================================
// Data I/O and Plotting
// =============================================================================
import $ivy.`org.plotly-scala::plotly-almond:0.8.2`
import $ivy.`com.github.tototoshi::scala-csv:1.3.10`

// =============================================================================
// Scientific Computing & Functional Programming Utilities
// =============================================================================
import $ivy.`org.scalanlp::breeze:2.1.0`
import $ivy.`org.typelevel::cats-core:2.9.0`


// =============================================================================
// Log levels are managed by SPARK_HOME/conf/log4j2.properties.
