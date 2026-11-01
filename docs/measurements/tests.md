## Concrete data to measure 

1. Kafka (via kafka_exporter → Prometheus)
	  - Consumer lag (*kafka_consumergroup_lag*): graph this live while `stream_processor` is stopped and restarted to watch lag build up and then drain (the drain rate is the heavy path's real throughput).
	  - Produce/consume throughput (bytes/sec, messages/sec) per topic
	  - Request latency (p50/p95/p99) on the producer side, retry/error rate

2. ClickHouse (via SQL against system.* tables, straight from Grafana's ClickHouse plugin)
	  - *system.query_log*: per-query duration, rows read, memory used for the two heavy-path queries (baseline velocity anomaly, device_ip_fan_out) as load increases.
	  - *system.part_log*: insert rate (rows/sec), merge frequency, part count over time (too many small parts mean write amplification, visible directly)
	  - *system.asynchronous_metrics*: memory pressure, background pool saturation.

3. App-level (PromEx in each of the 3 apps)
	  - ScoreTransaction gRPC latency p50/p95/p99: is the fast path staying fast under load?
	  - Verdict distribution (APPROVE/REVIEW/DECLINE) as a labeled counter.
	  - ETS table sizes (blocklist, velocity window) over time.
	  - Produce→consume gap (using the timestamp already in your Avro schema) as a custom "processing lag" metric in `stream_processor`.
