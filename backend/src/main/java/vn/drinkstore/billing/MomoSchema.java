package vn.drinkstore.billing;

import jakarta.annotation.PostConstruct;
import org.springframework.stereotype.Component;
import org.springframework.context.annotation.DependsOn;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.core.io.ClassPathResource;
import org.springframework.transaction.support.TransactionTemplate;
import java.nio.charset.StandardCharsets;

@Component
@DependsOn("receivingDatesSchema")
public class MomoSchema {
    private final JdbcTemplate jdbc;
    private final TransactionTemplate tx;
    public MomoSchema(JdbcTemplate jdbc,org.springframework.transaction.PlatformTransactionManager manager) { this.jdbc=jdbc; this.tx=new TransactionTemplate(manager); }
    @PostConstruct public void upgrade() throws java.io.IOException {
        String sql=new ClassPathResource("db/migrations/20261110_momo_sandbox.sql").getContentAsString(StandardCharsets.UTF_8);
        tx.executeWithoutResult(s->{
            jdbc.execute("select pg_advisory_xact_lock(77004120)");
            if(jdbc.queryForObject("select count(*) from backend_schema_migration where version='20261110_momo_sandbox'",Long.class)==0) {
                jdbc.execute(sql);
                jdbc.update("insert into backend_schema_migration(version) values ('20261110_momo_sandbox')");
            }
        });
    }
}
