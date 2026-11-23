CREATE TABLE IF NOT EXISTS payment_notification (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 payment_id bigint NOT NULL UNIQUE REFERENCES thanh_toan(id),
 order_id bigint NOT NULL REFERENCES don_hang(id),
 message text NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS checkout_request (
 customer_id bigint NOT NULL REFERENCES khach_hang(id),
 request_key uuid NOT NULL, fingerprint text NOT NULL,
 order_id bigint NOT NULL REFERENCES don_hang(id),
 PRIMARY KEY(customer_id,request_key)
);
