package vn.drinkstore.auth;

import java.sql.Timestamp;
import java.time.*;
import java.util.*;
import org.junit.jupiter.api.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import vn.drinkstore.common.*;
import vn.drinkstore.security.Tokens;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class PasswordResetServiceTest {
    final Db db=mock(Db.class);
    final JdbcTemplate jdbc=mock(JdbcTemplate.class);
    final PasswordEncoder encoder=mock(PasswordEncoder.class);
    final PasswordResetMail mail=mock(PasswordResetMail.class);
    final Instant now=Instant.parse("2026-11-08T06:00:00Z");
    final UUID id=UUID.randomUUID();
    final Map<String,Object> row=new HashMap<>();
    PasswordResetService service;
    @BeforeEach void setup() {
        when(db.jdbc()).thenReturn(jdbc);
        when(db.number(anyString(),anyLong())).thenReturn(1L);
        when(db.rows("select tai_khoan_id from password_reset_challenge where id=?",id)).thenReturn(List.of(Map.of("tai_khoan_id",7L)));
        when(db.one("select * from password_reset_challenge where id=? for update",id)).thenReturn(row);
        row.put("tai_khoan_id",7L); row.put("otp_hash","hashed-otp");
        row.put("so_lan_sai",0); row.put("da_dung",false);
        row.put("het_han",Timestamp.from(now.plusSeconds(300)));
        service=new PasswordResetService(db,encoder,mail,Runnable::run,Clock.fixed(now,ZoneOffset.UTC));
    }
    @Test void unknownEmailHasGenericResponseWithoutMailOrWrites() {
        var result=(Map<?,?>)service.request(" Missing@Test.invalid ");
        assertNotNull(result.get("challengeId")); assertFalse(result.containsKey("otp"));
        verify(mail).requireConfigured(); verify(mail,never()).send(anyString(),anyString());
        verifyNoInteractions(jdbc);
    }
    @Test void ineligibleAccountDoesNotReceiveOtp() {
        when(db.rows("select id,email from tai_khoan where lower(email)=? for update","staff@test.invalid")).thenReturn(List.of(Map.of("id",7L)));
        when(db.number(anyString(),anyLong())).thenReturn(0L);
        service.request("staff@test.invalid");
        verify(mail,never()).send(anyString(),anyString()); verifyNoInteractions(jdbc);
    }
    @Test void requestStoresOnlyHashAndSendsSixDigitCode() {
        when(db.rows("select id,email from tai_khoan where lower(email)=? for update","customer@test.invalid")).thenReturn(List.of(Map.of("id",7L)));
        when(encoder.encode(anyString())).thenReturn("bcrypt-hash");
        service.request("customer@test.invalid");
        verify(mail).send(eq("customer@test.invalid"),matches("[0-9]{6}"));
        verify(jdbc).update(startsWith("insert into password_reset_challenge"),any(UUID.class),eq(7L),eq("bcrypt-hash"),any(Timestamp.class),any(Timestamp.class));
    }
    @Test void deliveryWaitsUntilTransactionCommits() {
        when(db.rows("select id,email from tai_khoan where lower(email)=? for update","customer@test.invalid")).thenReturn(List.of(Map.of("id",7L)));
        org.springframework.transaction.support.TransactionSynchronizationManager.initSynchronization();
        try {
            service.request("customer@test.invalid");
            verify(mail,never()).send(anyString(),anyString());
            for(var callback:org.springframework.transaction.support.TransactionSynchronizationManager.getSynchronizations()) callback.afterCommit();
            verify(mail).send(eq("customer@test.invalid"),matches("[0-9]{6}"));
        } finally { org.springframework.transaction.support.TransactionSynchronizationManager.clearSynchronization(); }
    }
    @Test void wrongOtpErrorsDoNotRollBackAttemptCounter() throws Exception {
        var transaction=PasswordResetService.class.getMethod("verify",UUID.class,String.class)
            .getAnnotation(org.springframework.transaction.annotation.Transactional.class);
        assertTrue(Arrays.asList(transaction.noRollbackFor()).contains(ApiException.class));
    }
    @Test void wrongOtpConsumesAttemptWithoutIssuingGrant() {
        assertThrows(ApiException.class,()->service.verify(id,"111111"));
        verify(jdbc).update("update password_reset_challenge set so_lan_sai=least(so_lan_sai+1,5) where id=?",id);
        verify(encoder).matches("111111","hashed-otp");
    }
    @Test void expiredOrLockedOrUsedOtpIsRejectedBeforeHashComparison() {
        row.put("het_han",Timestamp.from(now));
        assertThrows(ApiException.class,()->service.verify(id,"111111"));
        row.put("het_han",Timestamp.from(now.plusSeconds(300))); row.put("so_lan_sai",5);
        assertThrows(ApiException.class,()->service.verify(id,"111111"));
        row.put("so_lan_sai",0); row.put("da_dung",true);
        assertThrows(ApiException.class,()->service.verify(id,"111111"));
        verifyNoInteractions(encoder,jdbc);
    }
    @Test void validOtpIsConsumedAndOnlyHashedGrantIsStored() {
        when(encoder.matches("123456","hashed-otp")).thenReturn(true);
        var result=(Map<?,?>)service.verify(id,"123456");
        String token=result.get("resetToken").toString(); assertEquals(43,token.length());
        verify(jdbc).update("update password_reset_challenge set otp_hash=null,reset_token_hash=?,reset_het_han=? where id=?",Tokens.hash(token),Timestamp.from(now.plusSeconds(300)),id);
    }
    @Test void invalidGrantCannotChangePassword() {
        row.put("reset_token_hash",Tokens.hash("expected")); row.put("reset_het_han",Timestamp.from(now.plusSeconds(300)));
        assertThrows(ApiException.class,()->service.complete(id,"wrong","NewPassword123!"));
        verifyNoInteractions(jdbc,encoder);
    }
    @Test void expiredGrantCannotChangePassword() {
        row.put("reset_token_hash",Tokens.hash("expected")); row.put("reset_het_han",Timestamp.from(now));
        assertThrows(ApiException.class,()->service.complete(id,"expected","NewPassword123!"));
        verifyNoInteractions(jdbc,encoder);
    }
    @Test void successfulResetRevokesSessionsAndAllChallenges() {
        row.put("reset_token_hash",Tokens.hash("expected")); row.put("reset_het_han",Timestamp.from(now.plusSeconds(300)));
        when(encoder.encode("NewPassword123!")).thenReturn("new-hash");
        service.complete(id,"expected","NewPassword123!");
        verify(jdbc).update("update tai_khoan set mat_khau_hash=?,so_lan_dang_nhap_sai=0,trang_thai='ACTIVE' where id=?","new-hash",7L);
        verify(jdbc).update("update phien_xac_thuc set da_thu_hoi=true where tai_khoan_id=?",7L);
        verify(jdbc).update("update password_reset_challenge set da_dung=true,otp_hash=null,reset_token_hash=null,reset_het_han=null where tai_khoan_id=? and not da_dung",7L);
        verify(db).audit(7L,"PASSWORD_RESET_OTP","tai_khoan",7L);
    }
}
