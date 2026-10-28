import re, json, glob, os, shutil, tempfile
from pyspark.sql import SparkSession
import pyspark.sql.functions as F

spark = (SparkSession.builder.master("local[2]").appName("t")
         .config("spark.sql.ansi.enabled", "true")      # Databricks SQL default
         .config("spark.ui.enabled", "false").getOrCreate())
spark.sparkContext.setLogLevel("ERROR")

SQL = open(__import__("pathlib").Path(__file__).resolve().parents[1] / "pipelines/silver/silver_pos.sql").read()
SQL = "\n".join(l for l in SQL.splitlines() if not l.strip().startswith("--"))
stmts = [s.strip() for s in re.split(r";\s*\n", SQL) if s.strip()]
def body(name):
    s = next(x for x in stmts if re.search(r"(STREAMING TABLE|MATERIALIZED VIEW) " + name + r"\b", x))
    return re.split(r"\nAS\n", s, maxsplit=1)[1]

SCHEMA = ("business_date STRING, store_id STRING, till_id STRING, receipts ARRAY<STRUCT<receipt_id:STRING,cashier_id:STRING,"
          "receipt_timestamp:STRING,status:STRING,corrected_from_receipt_id:STRING,receipt_total:STRING,"
          "lines:ARRAY<STRUCT<receipt_line_id:STRING,product_code:STRING,quantity:STRING,unit_price:STRING,discount_amount:STRING,promotion_code:STRING>>,"
          "payments:ARRAY<STRUCT<pos_payment_id:STRING,payment_method:STRING,amount:STRING,payment_status:STRING,currency:STRING>>>>")

def load_bronze(root_dirs):
    """Mimic bronze pos_raw: all primitives as text + _source_file + _ingested_at."""
    parts = []
    for d, ts in root_dirs:
        files = sorted(glob.glob(d + "/pos/*.json"))
        if not files: continue
        df = (spark.read.schema(SCHEMA).option("multiLine", True).json(files)
              .select("*", F.col("_metadata.file_path").alias("_source_file"))
              .withColumn("_ingested_at", F.lit(ts).cast("timestamp")))
        parts.append(df)
    out = parts[0]
    for p in parts[1:]: out = out.unionByName(p, allowMissingColumns=True)
    return out

def run(bronze):
    bronze.createOrReplaceTempView("pos_raw")
    q = body("slv_pos_receipts_parsed").replace("STREAM(mindit_training.bookstore_ec_bronze.pos_raw)", "pos_raw")
    parsed = spark.sql(q); parsed.createOrReplaceTempView("slv_pos_receipts_parsed")
    # emulate AUTO CDC SCD1: latest _ingested_at per key
    latest = spark.sql("""SELECT * EXCEPT (rn) FROM (SELECT *, row_number() OVER
        (PARTITION BY receipt_key ORDER BY _ingested_at DESC) rn FROM slv_pos_receipts_parsed) WHERE rn = 1""")
    latest.createOrReplaceTempView("slv_pos_receipts_latest")
    out = {"parsed": parsed}
    out["quarantine"] = spark.sql(body("dq_pos_receipts_quarantine").replace("STREAM(slv_pos_receipts_parsed)", "slv_pos_receipts_parsed"))
    for n in ("slv_pos_receipts", "slv_pos_receipt_lines", "slv_pos_payments"):
        out[n] = spark.sql(body(n))
    return out

B = str(__import__("pathlib").Path(__file__).resolve().parents[1] / "data/landing") + "/"
b1 = (B + "batch_01_arrived_2026-10-05", "2026-10-05 20:00:00")
b2 = (B + "batch_02_arrived_2026-10-07", "2026-10-07 20:00:00")

def net(o):
    return {str(r["business_date"]): float(r["s"]) for r in
            o["slv_pos_receipt_lines"].where("receipt_status='COMPLETED'").groupBy("business_date")
            .agg(F.sum("line_amount").alias("s")).collect()}

o1 = run(load_bronze([b1]))
print("batch1 net:", net(o1), "| quarantined:", o1["quarantine"].count())
assert net(o1) == {"2026-10-05": 295.0}

o2 = run(load_bronze([b1, b2]))
print("batch2 net:", net(o2), "| quarantined:", o2["quarantine"].count())
assert net(o2) == {"2026-10-05": 365.0, "2026-10-07": 85.0}
assert o2["quarantine"].count() == 0
late = [r["receipt_id"] for r in o2["slv_pos_receipts"].where("is_late_arrival").collect()]
print("late receipts:", late); assert late == ["REC006"]
# tenders: split payment for REC002
pay = o2["slv_pos_payments"].where("receipt_id='REC002'").agg(F.sum("amount")).collect()[0][0]
print("REC002 tenders:", pay); assert float(pay) == 75.0
# cancelled receipt is kept with status but has zero payments
print(o2["slv_pos_receipts"].where("status='CANCELLED'").select("receipt_id").collect())

# ---- negative cases: bad receipts + resend/late cancellation ----
tmp = tempfile.mkdtemp(); os.makedirs(tmp + "/pos")
bad = {"store_id": "ST001", "till_id": "T02", "business_date": "2026-10-08", "receipts": [
  {"receipt_id": "R_BAD1", "cashier_id": "C", "receipt_timestamp": "2026-10-08T09:00:00", "status": "COMPLETED",
   "corrected_from_receipt_id": "", "receipt_total": 100,
   "lines": [{"receipt_line_id": "L1", "product_code": "9780000001016", "quantity": 1, "unit_price": 40, "discount_amount": 0, "promotion_code": ""}],
   "payments": [{"pos_payment_id": "P1", "payment_method": "CARD", "amount": 40, "payment_status": "SUCCEEDED", "currency": "RON"}]},
  {"receipt_id": "R_BAD2", "cashier_id": "C", "receipt_timestamp": "not-a-date", "status": "COMPLETED",
   "corrected_from_receipt_id": "", "receipt_total": "abc", "lines": [], "payments": []},
  {"receipt_id": "R_OK", "cashier_id": "C", "receipt_timestamp": "2026-10-08T10:00:00", "status": "COMPLETED",
   "corrected_from_receipt_id": "", "receipt_total": 59.9,
   "lines": [{"receipt_line_id": "L2", "product_code": "9780000001047", "quantity": 1, "unit_price": 59.9, "discount_amount": 0, "promotion_code": ""}],
   "payments": [{"pos_payment_id": "P2", "payment_method": "CASH", "amount": 59.9, "payment_status": "SUCCEEDED", "currency": "RON"}]}]}
json.dump(bad, open(tmp + "/pos/ST001_T02_20261008.json", "w"))
# resend of REC007 as CANCELLED, arriving later
resend = json.load(open(B + "batch_02_arrived_2026-10-07/pos/ST001_T01_20261007.json"))
resend["receipts"][0]["status"] = "CANCELLED"; resend["receipts"][0]["payments"] = []
os.makedirs(tmp + "/r/pos"); json.dump(resend, open(tmp + "/r/pos/ST001_T01_20261007.json", "w"))
b3 = (tmp, "2026-10-09 20:00:00"); b4 = (tmp + "/r", "2026-10-10 20:00:00")
o3 = run(load_bronze([b1, b2, b3, b4]))
print("quarantine:", [(r["receipt_id"], r["failed_checks"]) for r in o3["quarantine"].collect()])
assert {r["receipt_id"] for r in o3["quarantine"].collect()} == {"R_BAD1", "R_BAD2"}
n3 = net(o3); print("net after bad+resend:", n3)
assert n3["2026-10-08"] == 59.9 and "2026-10-07" not in n3   # REC007 now cancelled -> no revenue
assert o3["slv_pos_receipts"].where("receipt_id='REC007'").count() == 1   # not duplicated
print("ALL SILVER POS TESTS PASSED")
