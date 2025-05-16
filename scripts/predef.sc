// ─── Load Spark library───────────────────────────────────────────────────
import $ivy.`org.apache.spark::spark-sql:3.3.2`

// ─── Suppress logs(driver) ──────────────────────────────────────────
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
