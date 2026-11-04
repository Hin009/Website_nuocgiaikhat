package vn.drinkstore.purchasing;

import jakarta.annotation.PostConstruct;
import org.springframework.context.annotation.DependsOn;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

@Component
@DependsOn("warehouseReturnsRemovalSchema")
public class ReceivingDatesSchema {
    public static final String VERSION="20261104_receiving_product_dates";
    public static final String DDL="""
ALTER TABLE public.chi_tiet_lan_nhap ADD COLUMN IF NOT EXISTS ngay_san_xuat date;
ALTER TABLE public.chi_tiet_lan_nhap ADD COLUMN IF NOT EXISTS ngay_het_han date;
DO $$ BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.chi_tiet_lan_nhap'::regclass AND conname='receipt_product_dates_check') THEN
  ALTER TABLE public.chi_tiet_lan_nhap ADD CONSTRAINT receipt_product_dates_check CHECK (
   (ngay_san_xuat IS NULL AND ngay_het_han IS NULL) OR
   (ngay_san_xuat IS NOT NULL AND ngay_het_han IS NOT NULL AND ngay_het_han>=ngay_san_xuat));
 END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_receipt_pending_purchase ON public.lan_nhap_hang(don_ncc_id) WHERE trang_thai='DRAFT';
INSERT INTO public.backend_schema_migration(version) VALUES ('20261104_receiving_product_dates') ON CONFLICT DO NOTHING;
        """;
    private final JdbcTemplate jdbc;
    private final TransactionTemplate tx;
    public ReceivingDatesSchema(JdbcTemplate jdbc,org.springframework.transaction.PlatformTransactionManager manager) {
        this.jdbc=jdbc; this.tx=new TransactionTemplate(manager);
    }
    @PostConstruct public void upgrade() {
        tx.executeWithoutResult(status->{
            jdbc.execute("select pg_advisory_xact_lock(77004120)");
            if(jdbc.queryForObject("select count(*) from backend_schema_migration where version=?",Long.class,VERSION)==0) jdbc.execute(DDL);
        });
    }
}
