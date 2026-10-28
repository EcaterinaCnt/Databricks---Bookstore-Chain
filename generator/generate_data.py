"""
Bookstore Scenario 1: deterministic synthetic SOURCE file generator.
Only Python standard library; run: python generator/generate_data.py
These files simulate operational exports, NOT normalized Silver tables.
"""
from __future__ import annotations
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'data' / 'landing'

def put_csv(batch: str, group: str, name: str, rows: list[dict]):
    path = OUT / batch / group / name
    path.parent.mkdir(parents=True, exist_ok=True)
    if not rows:
        raise ValueError(f'Cannot create an empty CSV: {name}') # Ensure we don't create empty CSV files
    with path.open('w', newline='', encoding='utf-8') as f: 
        writer = csv.DictWriter(f, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    return path # Return the path to the created CSV file


def put_json(batch: str, group: str, name: str, value: dict): # Write a JSON file to the landing area
    path = OUT / batch / group / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    return path # Return the path to the created JSON file


def ean13(prefix12: str) -> str: # Generate an EAN-13/ISBN-13 barcode from a 12-digit prefix
    """Generate an example checksum-valid EAN-13/ISBN-13 style barcode."""
    assert len(prefix12) == 12 and prefix12.isdigit()
    weighted_sum = sum(int(digit) * (1 if i % 2 == 0 else 3) for i, digit in enumerate(prefix12))
    return prefix12 + str((-weighted_sum) % 10) # Append the calculated check digit to the prefix


B1 = 'batch_01_arrived_2026-10-05'
B2 = 'batch_02_arrived_2026-10-07'

RULES = json.loads((ROOT / 'config' / 'business_rules.json').read_text(encoding='utf-8')) 
book = lambda n: ean13(f'978000000{n:03d}')
other = lambda n: ean13(f'594000000{n:03d}')
products = [
    dict(product_id='P101', product_code=book(101), title_id='T001', title='The Silent Forest', format='PAPERBACK', product_type='BOOK', publisher='North Star Press', list_price=40, status='ACTIVE'),
    dict(product_id='P102', product_code=book(102), title_id='T002', title='Hidden Truth', format='PAPERBACK', product_type='BOOK', publisher='Cedar Books', list_price=35, status='ACTIVE'),
    dict(product_id='P103', product_code=book(103), title_id='T003', title='The Last Summer', format='PAPERBACK', product_type='BOOK', publisher='Cedar Books', list_price=30, status='ACTIVE'),
    dict(product_id='P104', product_code=book(104), title_id='T001', title='The Silent Forest', format='HARDCOVER', product_type='BOOK', publisher='North Star Press', list_price=100, status='ACTIVE'),
    dict(product_id='P105', product_code=other(105), title_id='', title='Blue Notebook', format='', product_type='STATIONERY', publisher='', list_price=15, status='ACTIVE'),
    dict(product_id='P106', product_code=other(106), title_id='', title='Chess Board', format='', product_type='GAME', publisher='', list_price=70, status='ACTIVE'),
    dict(product_id='P107', product_code=other(107), title_id='', title='Bookmark Gift Set', format='', product_type='GIFT', publisher='', list_price=20, status='ACTIVE'),
    dict(product_id='P108', product_code=book(108), title_id='T004', title='Deep Ocean', format='HARDCOVER', product_type='BOOK', publisher='Maple House', list_price=90, status='ACTIVE'),
]
by_id = {p['product_id']: p for p in products}

def pcode(pid): return by_id[pid]['product_code']

def snapshot(day, overrides=None): # Create a snapshot of the product catalog for a given day, applying any overrides
    overrides = overrides or {} # Initialize overrides if not provided
    records = [] # Initialize the list of snapshot records
    for p in products:
        x = dict(snapshot_date=day, **p)
        x.update(overrides.get(p['product_id'], {}))
        records.append(x)
    return records

put_csv(B1, 'master', 'product_catalogue_20261005.csv', snapshot('2026-10-05'))# Create initial product catalogue snapshot for 2026-10-05
put_csv(B2, 'master', 'product_catalogue_20261007.csv', snapshot('2026-10-07', {'P104': {'list_price': 85}})) # Create product catalogue snapshot for 2026-10-07 with updated list price for P104
put_csv(B1, 'master', 'stores.csv', [ # Create initial stores data
    dict(store_id='ST001', store_name='Central Cluj', city='Cluj-Napoca', region_id='NW', manager_id='M001', open_date='2023-04-01', status='OPEN', till_count=2),
    dict(store_id='ST002', store_name='Sibiu Books', city='Sibiu', region_id='CTR', manager_id='M002', open_date='2022-06-15', status='OPEN', till_count=2),
    dict(store_id='ST003', store_name='Timisoara Plaza', city='Timisoara', region_id='W', manager_id='M003', open_date='2021-08-10', status='OPEN', till_count=1),
])
put_csv(B1, 'master', 'store_closures.csv', [ # Record store closures
    dict(store_id='ST003', closure_start='2026-10-05', closure_end='2026-10-08', reason='RENOVATION')
])

def line(no, product, qty, price, discount=0, promo=''):
    return dict(receipt_line_id=f'RL-{no}', product_code=pcode(product), quantity=qty, unit_price=price, discount_amount=discount, promotion_code=promo)

def payment(no, method, amount):
    return dict(pos_payment_id=f'PAY-{no}', payment_method=method, amount=amount, payment_status='SUCCEEDED', currency='RON')

def receipt(rid, till, ts, status, lines, payments, total, correction=''):
    return dict(receipt_id=rid, cashier_id='CASH001', receipt_timestamp=ts,
                status=status, corrected_from_receipt_id=correction, receipt_total=total,
                lines=lines, payments=payments)

# Standard sale; 3-for-2 promotion; cancelled incorrect receipt; corrected receipt.
promo = RULES['three_for_two']
for pid in ('P101', 'P102', 'P103'): # Ensure these products meet the promotion criteria
    p = by_id[pid]
    assert p['product_type'] == promo['product_type'] and p['format'] == promo['format'] and promo['min_unit_price'] <= p['list_price'] <= promo['max_unit_price']
r1 = receipt('REC001', 'T01', '2026-10-05T10:00:00', 'COMPLETED',
    [line('001', 'P101', 1, 40), line('002', 'P102', 1, 35), line('003', 'P105', 1, 15)], [payment('001','CARD',90)], 90)
r2 = receipt('REC002', 'T01', '2026-10-05T10:20:00', 'COMPLETED',
    [line('004','P101',1,40,0,'3FOR2'), line('005','P102',1,35,0,'3FOR2'), line('006','P103',1,30,30,'3FOR2')],
    [payment('002','CARD',50),payment('003','CASH',25)],75)
r3 = receipt('REC003', 'T01', '2026-10-05T11:00:00', 'CANCELLED',
    [line('007','P104',2,100)],[],200)
r4 = receipt('REC004', 'T01', '2026-10-05T11:05:00', 'COMPLETED',
    [line('008','P104',1,100)],[payment('004','CARD',100)],100,'REC003')
put_json(B1, 'pos', 'ST001_T01_20261005.json', dict(store_id='ST001',till_id='T01',business_date='2026-10-05',receipts=[r1,r2,r3,r4]))
r5 = receipt('REC005', 'T01', '2026-10-05T12:00:00', 'COMPLETED',
    [line('009','P103',1,30)],[payment('005','CASH',30)],30)
put_json(B1, 'pos', 'ST002_T01_20261005.json', dict(store_id='ST002',till_id='T01',business_date='2026-10-05',receipts=[r5]))
# Event date Oct 5, arrives Oct 7: actual late-arriving file.
r6 = receipt('REC006', 'T02', '2026-10-05T13:00:00', 'COMPLETED',
    [line('010','P106',1,70)],[payment('006','CARD',70)],70)
put_json(B2, 'pos', 'ST002_T02_20261005.json', dict(store_id='ST002',till_id='T02',business_date='2026-10-05',receipts=[r6]))
r7 = receipt('REC007', 'T01', '2026-10-07T10:00:00', 'COMPLETED',
    [line('011','P104',1,85)],[payment('007','CARD',85)],85)
put_json(B2, 'pos', 'ST001_T01_20261007.json', dict(store_id='ST001',till_id='T01',business_date='2026-10-07',receipts=[r7]))

orders = [ # Define online orders
    dict(order_id='O5001', customer_id='', placed_at='2026-10-05T11:00:00', delivery_city='Cluj-Napoca', shipping_fee=10, order_total=85),
    dict(order_id='O5002', customer_id='', placed_at='2026-10-05T12:00:00', delivery_city='Bistrita', shipping_fee=10, order_total=55),
    dict(order_id='O5003', customer_id='', placed_at='2026-10-05T13:00:00', delivery_city='Suceava', shipping_fee=10, order_total=110),
]
orderlines = [ # Define order lines for the online orders
    dict(order_line_id='OL001',order_id='O5001',product_code=pcode('P101'),quantity=1,unit_price=40,discount_amount=0),
    dict(order_line_id='OL002',order_id='O5001',product_code=pcode('P102'),quantity=1,unit_price=35,discount_amount=0),
    dict(order_line_id='OL003',order_id='O5002',product_code=pcode('P103'),quantity=1,unit_price=30,discount_amount=0),
    dict(order_line_id='OL004',order_id='O5002',product_code=pcode('P105'),quantity=1,unit_price=15,discount_amount=0),
    dict(order_line_id='OL005',order_id='O5003',product_code=pcode('P104'),quantity=1,unit_price=100,discount_amount=0),
]
put_csv(B1,'online','online_orders.csv',orders)
put_csv(B1,'online','online_order_lines.csv',orderlines)
statuses = [ # Define status updates for the online orders
    dict(order_id='O5001',status='PLACED',status_event_timestamp='2026-10-05T11:00:00'),
    dict(order_id='O5001',status='PAID',status_event_timestamp='2026-10-05T11:07:00'),
    dict(order_id='O5001',status='CANCELLED',status_event_timestamp='2026-10-05T11:40:00'),
    dict(order_id='O5002',status='PLACED',status_event_timestamp='2026-10-05T12:00:00'),
    dict(order_id='O5002',status='PAID',status_event_timestamp='2026-10-05T12:05:00'),
    dict(order_id='O5003',status='PLACED',status_event_timestamp='2026-10-05T13:00:00'),
    dict(order_id='O5003',status='CANCELLED',status_event_timestamp='2026-10-05T13:15:00'),
]
put_csv(B1,'online','online_order_status.csv',statuses)
# O5002 PAID repeated on the next export: a duplicate business event to deduplicate in Silver.
put_csv(B2,'online','online_order_status.csv',[
    statuses[4],
    dict(order_id='O5002',status='READY_FOR_DELIVERY',status_event_timestamp='2026-10-05T18:00:00'),
    dict(order_id='O5002',status='SHIPPED',status_event_timestamp='2026-10-06T09:00:00'),
    dict(order_id='O5002',status='DELIVERED',status_event_timestamp='2026-10-07T18:00:00'),
])

payment_events = [
    dict(payment_event_id='PE001',payment_id='PMT001',original_payment_id='',order_id='O5001',event_type='CHARGE',status='PENDING',product_amount=75,shipping_amount=10,amount=85,currency='RON',event_timestamp='2026-10-05T11:02:00',refund_reason=''),
    dict(payment_event_id='PE002',payment_id='PMT001',original_payment_id='',order_id='O5001',event_type='CHARGE',status='SUCCEEDED',product_amount=75,shipping_amount=10,amount=85,currency='RON',event_timestamp='2026-10-05T11:07:00',refund_reason=''),
    dict(payment_event_id='PE003',payment_id='RFD001',original_payment_id='PMT001',order_id='O5001',event_type='REFUND',status='SUCCEEDED',product_amount=75,shipping_amount=10,amount=85,currency='RON',event_timestamp='2026-10-05T11:50:00',refund_reason='ORDER_CANCELLATION'),
    dict(payment_event_id='PE004',payment_id='PMT002',original_payment_id='',order_id='O5002',event_type='CHARGE',status='SUCCEEDED',product_amount=45,shipping_amount=10,amount=55,currency='RON',event_timestamp='2026-10-05T12:05:00',refund_reason=''),
    dict(payment_event_id='PE005',payment_id='PMT003',original_payment_id='',order_id='O5003',event_type='CHARGE',status='FAILED',product_amount=100,shipping_amount=10,amount=110,currency='RON',event_timestamp='2026-10-05T13:05:00',refund_reason=''),
]
put_csv(B1,'online','online_payments.csv',payment_events)

print('Generated 2 arrival batches under:', OUT)
print('Source CSV/JSON count:', len(list(OUT.rglob('*.csv'))) + len(list(OUT.rglob('*.json'))))
print('Fixture expected: online net=55 RON; POS net day1 after late file=365 RON; POS Oct7=85 RON')
