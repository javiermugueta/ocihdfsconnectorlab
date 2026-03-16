package com.example.banking;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.IntWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;
import org.apache.hadoop.util.GenericOptionsParser;

public class DailyBalanceJob {
  public static void main(String[] args) throws Exception {
    Configuration conf = new Configuration();
    String[] remainingArgs = new GenericOptionsParser(conf, args).getRemainingArgs();
    if (remainingArgs.length != 2) {
      System.err.println("Uso: DailyBalanceJob <input-uri> <output-uri>");
      System.exit(1);
    }

    Job job = Job.getInstance(conf, "daily-balance-banking-job");

    job.setJarByClass(DailyBalanceJob.class);
    job.setMapperClass(TransactionMapper.class);
    job.setReducerClass(DailyBalanceReducer.class);

    job.setMapOutputKeyClass(Text.class);
    job.setMapOutputValueClass(IntWritable.class);
    job.setOutputKeyClass(Text.class);
    job.setOutputValueClass(IntWritable.class);

    FileInputFormat.addInputPath(job, new Path(remainingArgs[0]));
    FileOutputFormat.setOutputPath(job, new Path(remainingArgs[1]));

    System.exit(job.waitForCompletion(true) ? 0 : 2);
  }
}
