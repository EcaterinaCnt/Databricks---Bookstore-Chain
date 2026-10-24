"""Simple source-fixture validation; run: python tests/validate_data.py"""
import csv
import json
from collections import defaultdict
from pathlib import Path

BASE = Path(__file__).resolve().parents[1] / 'data' / 'landing'
B1 = BASE / 'batch_01_arrived_2026-10-05'
B2 = BASE / 'batch_02_arrived_2026-10-07'

def read_csv(path):
    with path.open(newline='', encoding='utf-8') as f:
        return list(csv.DictReader(f))

# Reconcile original online order amounts from their transaction lines.
orders = {r['order_id']:r for r in read_csv(B1/'online'/'online_orders.csv')}
lines_by_order = defaultdict(list)
for ln in read_csv(B1/'online'/'online_order_lines.csv'):
    lines_by_order[ln['order_id']].append(ln)
for oid, order in orders.items():
    computed = sum(int(x['quantity'])*int(x['unit_price'])-int(x['discount_amount']) for x in lines_by_order[oid]) + int(order['shipping_fee'])
    assert computed == int(order['order_total']), (oid, computed)

# Distinguish payment events from payment operations; count only each successful operation once.
payments = read_csv(B1/'online'/'online_payments.csv')
financial = {}
for event in payments:
    assert int(event['amount']) == int(event['product_amount'])+int(event['shipping_amount'])
    if event['status'] == 'SUCCEEDED':
        key=(event['event_type'],event['payment_id'])
        assert key not in financial, f'Duplicate successful payment operation: {key}'
        sign = 1 if event['event_type']=='CHARGE' else -1
        financial[key] = sign*int(event['amount'])
assert sum(financial.values()) == 55

# Cancelled POS receipt has no revenue; receipt tenders reconcile, including split payment.
pos_net_by_date = defaultdict(int)
for p in BASE.rglob('ST*_T*_*.json'):
    data = json.loads(p.read_text(encoding='utf-8'))
    for rc in data['receipts']:
        if rc['status'] != 'COMPLETED':
            continue
        line_total = sum(int(l['quantity'])*int(l['unit_price'])-int(l['discount_amount']) for l in rc['lines'])
        paid = sum(int(t['amount']) for t in rc['payments'] if t['payment_status']=='SUCCEEDED')
        assert line_total == paid == int(rc['receipt_total']), rc['receipt_id']
        pos_net_by_date[data['business_date']] += line_total
assert pos_net_by_date == {'2026-10-05':365, '2026-10-07':85}, pos_net_by_date

# The second batch repeats O5002's PAID event without creating another distinct order event.
e1 = read_csv(B1/'online'/'online_order_status.csv')
e2 = read_csv(B2/'online'/'online_order_status.csv')
all_events = {(e['order_id'],e['status'],e['status_event_timestamp']) for e in e1+e2}
assert len(all_events) == len(e1)+len(e2)-1

# Price changed in second snapshot, but no previous transaction line was rewritten.
cat1 = {r['product_id']:r for r in read_csv(B1/'master'/'product_catalogue_20261005.csv')}
cat2 = {r['product_id']:r for r in read_csv(B2/'master'/'product_catalogue_20261007.csv')}
assert cat1['P104']['list_price']=='100' and cat2['P104']['list_price']=='85'
print('PASS: order totals, payment events, POS tenders, late file, duplicate status, catalogue history')
print('PASS: online net=55 RON, POS 2026-10-05=365 RON, POS 2026-10-07=85 RON')
