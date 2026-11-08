package vn.drinkstore.purchasing;

import jakarta.annotation.PostConstruct;
import org.springframework.context.annotation.DependsOn;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

@Component
@DependsOn("automaticPricingSchema")
public class RoundedSellingPricesSchema {
    public static final String VERSION="20261107_round_selling_prices_500";
    public static final String DDL="""
CREATE OR REPLACE FUNCTION public.fn_automatic_sale_price(cost NUMERIC)
RETURNS NUMERIC LANGUAGE sql IMMUTABLE STRICT AS $$ SELECT ceil(cost*1.25/500)*500 $$;
-- Reprice only rows already using the preceding automatic markup rule.
-- Cost, stock, debt and historical order-line snapshots are not rewritten.
UPDATE public.quy_cach_san_pham SET gia_ban=public.fn_automatic_sale_price(gia_von)
WHERE gia_ban=round(gia_von*1.25,2) AND gia_ban<>public.fn_automatic_sale_price(gia_von);
INSERT INTO public.backend_schema_migration(version) VALUES ('20261107_round_selling_prices_500') ON CONFLICT DO NOTHING;
        """;
    private final JdbcTemplate jdbc;
    private final TransactionTemplate tx;
    public RoundedSellingPricesSchema(JdbcTemplate jdbc,org.springframework.transaction.PlatformTransactionManager manager) {
        this.jdbc=jdbc; this.tx=new TransactionTemplate(manager);
    }
    @PostConstruct public void upgrade() {
        tx.executeWithoutResult(status->{
            jdbc.execute("select pg_advisory_xact_lock(77004123)");
            if(jdbc.queryForObject("select count(*) from public.backend_schema_migration where version=?",Long.class,VERSION)==0) jdbc.execute(DDL);
        });
    }
}
