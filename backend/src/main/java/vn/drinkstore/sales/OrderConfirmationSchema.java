package vn.drinkstore.sales;

import jakarta.annotation.PostConstruct;
import java.nio.charset.StandardCharsets;
import org.springframework.context.annotation.DependsOn;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

@Component
@DependsOn("checkoutSchema")
public class OrderConfirmationSchema {
    public static final String VERSION="20261111_order_confirmation";
    private final JdbcTemplate jdbc;
    private final TransactionTemplate tx;
    public OrderConfirmationSchema(JdbcTemplate jdbc,org.springframework.transaction.PlatformTransactionManager manager) {
        this.jdbc=jdbc; this.tx=new TransactionTemplate(manager);
    }
    @PostConstruct public void upgrade() throws java.io.IOException {
        String sql=new ClassPathResource("db/migrations/20261111_order_confirmation.sql").getContentAsString(StandardCharsets.UTF_8);
        tx.executeWithoutResult(status->{
            jdbc.execute("select pg_advisory_xact_lock(77004120)");
            if(jdbc.queryForObject("select count(*) from backend_schema_migration where version=?",Long.class,VERSION)==0) {
                jdbc.execute(sql);
                jdbc.update("insert into backend_schema_migration(version) values (?)",VERSION);
            }
        });
    }
}
