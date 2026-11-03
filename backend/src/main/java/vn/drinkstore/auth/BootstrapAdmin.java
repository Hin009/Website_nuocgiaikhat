package vn.drinkstore.auth;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.*;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;
import vn.drinkstore.common.Db;

@Component
public class BootstrapAdmin implements ApplicationRunner {
    private final Db db; private final AuthService auth; private final TransactionTemplate tx;
    private final String email,password;
    public BootstrapAdmin(Db db,AuthService auth,TransactionTemplate tx,
        @Value("${app.bootstrap.email}") String email,@Value("${app.bootstrap.password}") String password) {
        this.db=db; this.auth=auth; this.tx=tx; this.email=email; this.password=password;
    }
    @Override public void run(ApplicationArguments args) {
        if(password.isBlank()) return;
        if(password.length()<12 || password.length()>72) throw new IllegalArgumentException("Bootstrap password requires 12..72 characters");
        tx.executeWithoutResult(s->{
            // Serializes concurrent first starts without changing the existing schema.
            db.jdbc().execute("select pg_advisory_xact_lock(13092026)");
            if(db.number("select count(*) from tai_khoan_vai_tro ar join vai_tro r on r.id=ar.vai_tro_id where r.ma_vai_tro='QUAN_TRI_VIEN'")>0) return;
            long id=auth.createAccount(email,password,"QUAN_TRI_VIEN");
            db.jdbc().update("insert into nhan_vien(tai_khoan_id,ma_nhan_vien,ho_ten,chuc_vu,ngay_vao_lam) values (?,'NV-'||?::text,'Quản trị viên','ADMIN',current_date)",id,id);
        });
    }
}
