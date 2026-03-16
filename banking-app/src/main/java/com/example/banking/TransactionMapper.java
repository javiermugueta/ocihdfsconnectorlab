package com.example.banking;

import java.io.IOException;
import org.apache.hadoop.io.IntWritable;
import org.apache.hadoop.io.LongWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Mapper;

public class TransactionMapper extends Mapper<LongWritable, Text, Text, IntWritable> {
  private static final IntWritable AMOUNT = new IntWritable();
  private final Text accountDay = new Text();

  @Override
  protected void map(LongWritable key, Text value, Context context) throws IOException, InterruptedException {
    String line = value.toString();
    if (line.startsWith("txn_id")) {
      return;
    }

    String[] cols = line.split(",");
    if (cols.length < 6) {
      return;
    }

    String date = cols[1].trim();
    String accountId = cols[2].trim();
    String txnType = cols[4].trim();
    int amount = Integer.parseInt(cols[5].trim());

    int signedAmount = "DEBIT".equalsIgnoreCase(txnType) ? -amount : amount;
    accountDay.set(accountId + "|" + date);
    AMOUNT.set(signedAmount);
    context.write(accountDay, AMOUNT);
  }
}
