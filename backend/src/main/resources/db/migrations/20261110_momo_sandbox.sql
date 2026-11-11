CREATE TABLE IF NOT EXISTS momo_payment_attempt (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 payment_id bigint NOT NULL REFERENCES thanh_toan(id),
 momo_order_id varchar(100) NOT NULL UNIQUE,
 request_id varchar(100) NOT NULL UNIQUE,
 environment varchar(10) NOT NULL DEFAULT 'SANDBOX' CHECK (environment='SANDBOX'),
 amount bigint NOT NULL CHECK (amount>0),
 status varchar(20) NOT NULL DEFAULT 'CREATED' CHECK (status IN ('CREATED','PENDING','FAILED','SUCCESS')),
 order_info text NOT NULL, redirect_url text NOT NULL, ipn_url text NOT NULL,
 pay_url text, qr_code_data text, trans_id varchar(100) UNIQUE,
 result_code integer, message text, paid_at timestamptz, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS momo_one_active_attempt ON momo_payment_attempt(payment_id) WHERE status IN ('CREATED','PENDING');
CREATE TABLE IF NOT EXISTS momo_ipn_history (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 attempt_id bigint NOT NULL REFERENCES momo_payment_attempt(id),
 payload jsonb NOT NULL, received_at timestamptz NOT NULL DEFAULT now()
);
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
