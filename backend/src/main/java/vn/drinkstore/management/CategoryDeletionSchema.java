package vn.drinkstore.management;

import jakarta.annotation.PostConstruct;
import org.springframework.context.annotation.DependsOn;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

@Component
@DependsOn("purchasingSchema")
public class CategoryDeletionSchema {
    public static final String VERSION="20261114_category_deletion";
    private final JdbcTemplate jdbc;
    private final TransactionTemplate tx;
    public CategoryDeletionSchema(JdbcTemplate jdbc,org.springframework.transaction.PlatformTransactionManager manager) {
        this.jdbc=jdbc; this.tx=new TransactionTemplate(manager);
    }
    @PostConstruct public void upgrade() {
        tx.executeWithoutResult(status->{
            jdbc.execute("select pg_advisory_xact_lock(77004127)");
            if(jdbc.queryForObject("select count(*) from backend_schema_migration where version=?",Long.class,VERSION)==0) {
                jdbc.execute("alter table loai_san_pham add column if not exists deleted_at timestamptz");
                jdbc.execute("alter table loai_san_pham add constraint deleted_category_hidden check (deleted_at is null or not hien_thi)");
                jdbc.update("insert into backend_schema_migration(version) values (?)",VERSION);
            }
        });
    }
}
