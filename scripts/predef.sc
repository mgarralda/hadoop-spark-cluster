// =============================================================================
// Force JVM to use custom Log4j2 configuration
// =============================================================================
System.setProperty("log4j.configurationFile", "/usr/local/spark/conf/log4j2.properties")

// =============================================================================
// Spark Core + ML Libraries
// =============================================================================
import $ivy.`org.apache.spark::spark-sql:3.3.2`
import $ivy.`org.apache.spark::spark-mllib:3.3.2`
import $ivy.`org.apache.spark::spark-graphx:3.3.2`

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
// Optional (still valid if using log4j 1.x)
// =============================================================================
import org.apache.log4j.{Level, Logger}

Logger.getLogger("org").setLevel(Level.ERROR)
Logger.getLogger("org.apache").setLevel(Level.ERROR)
Logger.getLogger("org.apache.spark").setLevel(Level.ERROR)
Logger.getLogger("org.apache.spark.scheduler").setLevel(Level.ERROR)
Logger.getLogger("org.apache.spark.storage").setLevel(Level.ERROR)
Logger.getLogger("org.apache.spark.sql.execution").setLevel(Level.ERROR)
Logger.getLogger("org.apache.spark.ui").setLevel(Level.ERROR)
Logger.getLogger("org.apache.spark.deploy").setLevel(Level.ERROR)
Logger.getLogger("org.apache.spark.repl.Main").setLevel(Level.ERROR)
Logger.getLogger("org.spark_project.jetty").setLevel(Level.OFF)
Logger.getRootLogger.setLevel(Level.ERROR)
