package vn.drinkstore.purchasing;

import jakarta.annotation.PostConstruct;
import org.springframework.context.annotation.DependsOn;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

/** Retire warehouse returns; receiving-time rejection remains in receipt lines. */
@Component
@DependsOn("receivingWorkflowSchema")
public class WarehouseReturnsRemovalSchema {
    public static final String VERSION="20261104_remove_warehouse_returns";
    public static final String DDL="""
DO $$ BEGIN
 IF to_regclass('public.phieu_tra_ncc') IS NOT NULL THEN
  IF EXISTS (SELECT 1 FROM phieu_tra_ncc WHERE trang_thai='DRAFT' OR so_tien_cho_hoan>so_tien_da_hoan) THEN
   RAISE EXCEPTION 'Cannot retire warehouse returns with unresolved quarantine or refunds';
  END IF;
 END IF;
END $$;
DROP TABLE IF EXISTS hoan_tien_tra_ncc,chi_tiet_tra_ncc,phieu_tra_ncc;
DROP FUNCTION IF EXISTS fn_protect_supplier_return_lines();
INSERT INTO backend_schema_migration(version) VALUES ('20261104_remove_warehouse_returns') ON CONFLICT DO NOTHING;
        """;
    private final JdbcTemplate jdbc;
    private final TransactionTemplate tx;
    public WarehouseReturnsRemovalSchema(JdbcTemplate jdbc,org.springframework.transaction.PlatformTransactionManager manager) {
        this.jdbc=jdbc; this.tx=new TransactionTemplate(manager);
    }
    @PostConstruct public void upgrade() {
        tx.executeWithoutResult(status->{
            jdbc.execute("select pg_advisory_xact_lock(77004120)");
            if(jdbc.queryForObject("select count(*) from backend_schema_migration where version=?",Long.class,VERSION)==0) jdbc.execute(DDL);
        });
    }
}
