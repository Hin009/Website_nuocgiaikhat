package vn.drinkstore.auth;

import jakarta.annotation.PostConstruct;
import org.springframework.context.annotation.DependsOn;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

@Component
@DependsOn("passwordResetSchema")
public class EmailChangeSchema {
    public static final String VERSION="20261117_email_change_otp";
    public static final String DDL="""
        CREATE TABLE IF NOT EXISTS email_change_challenge (
          id uuid PRIMARY KEY,
          tai_khoan_id bigint NOT NULL REFERENCES tai_khoan(id) ON DELETE CASCADE,
          session_hash varchar(64) NOT NULL,
          old_email varchar(255) NOT NULL,
          new_email varchar(255),
          stage varchar(24) NOT NULL CHECK(stage IN ('CURRENT_OTP','CURRENT_VERIFIED','NEW_OTP','COMPLETED','CANCELLED')),
          otp_hash varchar(100),
          expires_at timestamptz NOT NULL,
          attempts integer NOT NULL DEFAULT 0 CHECK(attempts BETWEEN 0 AND 5),
          verified_until timestamptz,
          last_sent_at timestamptz NOT NULL DEFAULT now(),
          delivery_failed boolean NOT NULL DEFAULT false,
          created_at timestamptz NOT NULL DEFAULT now()
        );
        CREATE INDEX IF NOT EXISTS idx_email_change_account ON email_change_challenge(tai_khoan_id,created_at DESC);
        INSERT INTO backend_schema_migration(version) VALUES ('20261117_email_change_otp') ON CONFLICT DO NOTHING;
        """;
    private final JdbcTemplate jdbc;
    private final TransactionTemplate tx;
    public EmailChangeSchema(JdbcTemplate jdbc,org.springframework.transaction.PlatformTransactionManager manager) {
        this.jdbc=jdbc; this.tx=new TransactionTemplate(manager);
    }
    @PostConstruct public void upgrade() {
        tx.executeWithoutResult(status -> {
            jdbc.execute("select pg_advisory_xact_lock(77004131)");
            if(jdbc.queryForObject("select count(*) from backend_schema_migration where version=?",Long.class,VERSION)==0) jdbc.execute(DDL);
        });
    }
}
