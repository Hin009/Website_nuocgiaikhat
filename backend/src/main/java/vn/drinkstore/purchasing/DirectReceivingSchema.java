package vn.drinkstore.purchasing;

import jakarta.annotation.PostConstruct;
import org.springframework.context.annotation.DependsOn;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

/** DA_DUYET is retained as the existing database's ready-to-receive state. */
@Component
@DependsOn("receivingDatesSchema")
public class DirectReceivingSchema {
    public static final String VERSION="20261104_direct_receiving";
    public static final String DDL="""
ALTER TABLE public.don_dat_hang_ncc ALTER COLUMN trang_thai SET DEFAULT 'DA_DUYET';
UPDATE public.don_dat_hang_ncc SET trang_thai='DA_DUYET' WHERE trang_thai='CHO_DUYET';
INSERT INTO public.backend_schema_migration(version) VALUES ('20261104_direct_receiving') ON CONFLICT DO NOTHING;
        """;
    private final JdbcTemplate jdbc;
    private final TransactionTemplate tx;
    public DirectReceivingSchema(JdbcTemplate jdbc,org.springframework.transaction.PlatformTransactionManager manager) {
        this.jdbc=jdbc; this.tx=new TransactionTemplate(manager);
    }
    @PostConstruct public void upgrade() {
        tx.executeWithoutResult(status->{
            jdbc.execute("select pg_advisory_xact_lock(77004121)");
            if(jdbc.queryForObject("select count(*) from public.backend_schema_migration where version=?",Long.class,VERSION)==0) jdbc.execute(DDL);
        });
    }
}
