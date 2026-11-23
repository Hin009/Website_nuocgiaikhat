package vn.drinkstore.billing;

import jakarta.annotation.PostConstruct;
import org.springframework.context.annotation.DependsOn;
import org.springframework.stereotype.Component;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.support.TransactionTemplate;

@Component
@DependsOn("checkoutSchema")
public class BankTransferSchema {
    private final JdbcTemplate jdbc;
    private final TransactionTemplate tx;
    public BankTransferSchema(JdbcTemplate jdbc,org.springframework.transaction.PlatformTransactionManager manager) {
        this.jdbc=jdbc; this.tx=new TransactionTemplate(manager);
    }
    @PostConstruct public void upgrade() throws java.io.IOException {
        String version="20261120_bank_transfer_confirmation";
        String sql=new org.springframework.core.io.ClassPathResource("db/migrations/"+version+".sql")
            .getContentAsString(java.nio.charset.StandardCharsets.UTF_8);
        tx.executeWithoutResult(s->{
            jdbc.execute("select pg_advisory_xact_lock(77004120)");
            if(jdbc.queryForObject("select count(*) from backend_schema_migration where version=?",Long.class,version)==0) {
                jdbc.execute(sql);
                jdbc.update("insert into backend_schema_migration(version) values (?)",version);
            }
        });
    }
}
