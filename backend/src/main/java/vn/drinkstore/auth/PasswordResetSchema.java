package vn.drinkstore.auth;

import jakarta.annotation.PostConstruct;
import org.springframework.context.annotation.DependsOn;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

@Component
@DependsOn("roundedSellingPricesSchema")
public class PasswordResetSchema {
    public static final String VERSION="20261108_customer_password_reset";
    public static final String DDL="""
CREATE TABLE IF NOT EXISTS public.password_reset_challenge (
 id uuid PRIMARY KEY,
 tai_khoan_id bigint NOT NULL REFERENCES public.tai_khoan(id) ON DELETE CASCADE,
 otp_hash varchar(100),
 het_han timestamptz NOT NULL,
 so_lan_sai integer NOT NULL DEFAULT 0 CHECK(so_lan_sai BETWEEN 0 AND 5),
 reset_token_hash varchar(64),
 reset_het_han timestamptz,
 da_dung boolean NOT NULL DEFAULT false,
 gui_that_bai boolean NOT NULL DEFAULT false,
 tao_luc timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_reset_account_created ON public.password_reset_challenge(tai_khoan_id,tao_luc DESC);
INSERT INTO public.backend_schema_migration(version) VALUES ('20261108_customer_password_reset') ON CONFLICT DO NOTHING;
        """;
    private final JdbcTemplate jdbc;
    private final TransactionTemplate tx;
    public PasswordResetSchema(JdbcTemplate jdbc,org.springframework.transaction.PlatformTransactionManager manager) {
        this.jdbc=jdbc; this.tx=new TransactionTemplate(manager);
    }
    @PostConstruct public void upgrade() {
        tx.executeWithoutResult(status->{
            jdbc.execute("select pg_advisory_xact_lock(77004124)");
            if(jdbc.queryForObject("select count(*) from public.backend_schema_migration where version=?",Long.class,VERSION)==0) jdbc.execute(DDL);
        });
    }
}
