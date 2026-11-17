package vn.drinkstore.auth;
import java.sql.Timestamp;
import java.time.*;
import java.util.*;
import org.junit.jupiter.api.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import vn.drinkstore.common.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
class EmailChangeServiceTest {
    final Db db=mock(Db.class);
    final JdbcTemplate jdbc=mock(JdbcTemplate.class);
    final PasswordEncoder encoder=mock(PasswordEncoder.class);
    final PasswordResetMail mail=mock(PasswordResetMail.class);
    final EmailChangeRateLimit limits=mock(EmailChangeRateLimit.class);
    final Instant now=Instant.parse("2026-11-17T05:00:00Z");
    final UUID id=UUID.randomUUID();
    final String session="session-hash";
    final Map<String,Object> row=new HashMap<>();
    EmailChangeService service;
    @BeforeEach void setup() {
        when(db.jdbc()).thenReturn(jdbc);
        when(db.one("select id,email,trang_thai from tai_khoan where id=? and deleted_at is null for update",7L)).thenReturn(Map.of("id",7L,"email","old@test.invalid","trang_thai","ACTIVE"));
        when(db.rows("select * from email_change_challenge where id=? and tai_khoan_id=? and session_hash=? for update",id,7L,session)).thenReturn(List.of(row));
        row.put("old_email","old@test.invalid"); row.put("new_email","new@test.invalid"); row.put("stage","NEW_OTP"); row.put("otp_hash","hashed-code");
        row.put("verified_until",Timestamp.from(now.plusSeconds(600))); row.put("attempts",0); row.put("created_at",Timestamp.from(now)); row.put("last_sent_at",Timestamp.from(now)); row.put("expires_at",Timestamp.from(now.plusSeconds(300)));
        when(encoder.encode(anyString())).thenReturn("new-hashed-code");
        service=new EmailChangeService(db,encoder,mail,limits,Runnable::run,Clock.fixed(now,ZoneOffset.UTC));
    }
    @Test void currentEmailIsReadFromAccountAndOtpIsSentAfterCommit() {
        TransactionSynchronizationManager.initSynchronization();
        try {
            var result=(Map<?,?>)service.requestCurrent(7L,session,"ip");
            assertEquals("old@test.invalid",result.get("email"));
            assertFalse(result.containsKey("code")); assertFalse(result.containsKey("otp"));
            verify(mail,never()).sendEmailChange(anyString(),anyString(),anyBoolean());
            for(var callback:TransactionSynchronizationManager.getSynchronizations()) callback.afterCommit();
            verify(mail).sendEmailChange(eq("old@test.invalid"),matches("[0-9]{6}"),eq(false));
            verify(mail,never()).sendEmailChange(eq("new@test.invalid"),anyString(),anyBoolean());
            verify(jdbc).update(startsWith("insert into email_change_challenge"),any(UUID.class),eq(7L),eq(session),eq("old@test.invalid"),eq("new-hashed-code"),any(Timestamp.class),any(Timestamp.class),any(Timestamp.class));
        } finally { TransactionSynchronizationManager.clearSynchronization(); }
    }
    @Test void wrongCodeConsumesAttemptAndSkipsRollback() throws Exception {
        assertThrows(EmailChangeService.WrongCode.class,()->service.verifyNew(7L,session,id,"111111","ip"));
        verify(jdbc).update("update email_change_challenge set attempts=least(attempts+1,5) where id=?",id);
        var annotation=EmailChangeService.class.getMethod("verifyNew",long.class,String.class,UUID.class,String.class,String.class).getAnnotation(org.springframework.transaction.annotation.Transactional.class);
        assertArrayEquals(new Class<?>[]{EmailChangeService.WrongCode.class},annotation.noRollbackFor());
    }
    @Test void expiredOrExhaustedOtpCannotBeVerified() {
        row.put("expires_at",Timestamp.from(now));
        assertThrows(ApiException.class,()->service.verifyNew(7L,session,id,"123456","ip"));
        row.put("expires_at",Timestamp.from(now.plusSeconds(300))); row.put("attempts",5);
        assertThrows(ApiException.class,()->service.verifyNew(7L,session,id,"123456","ip"));
        verifyNoInteractions(encoder,jdbc);
    }
    @Test void newEmailMustBeDifferentAndAvailable() {
        assertThrows(ApiException.class,()->service.requestNew(7L,session,id,"OLD@test.invalid","ip"));
        when(db.number("select count(*) from tai_khoan where lower(email)=? and id<>?","taken@test.invalid",7L)).thenReturn(1L);
        assertThrows(ApiException.class,()->service.requestNew(7L,session,id,"taken@test.invalid","ip"));
        verifyNoInteractions(jdbc);
    }
    @Test void successfulVerificationUpdatesEmailAndRevokesOtherSessions() {
        when(encoder.matches("654321","hashed-code")).thenReturn(true);
        var result=(Map<?,?>)service.verifyNew(7L,session,id,"654321","ip");
        assertEquals("new@test.invalid",result.get("email"));
        verify(jdbc).update("update tai_khoan set email=?,email_da_xac_thuc=true where id=?","new@test.invalid",7L);
        verify(jdbc).update("update phien_xac_thuc set da_thu_hoi=true where tai_khoan_id=? and token_hash<>?",7L,session);
        verify(db).audit(7L,"EMAIL_CHANGE_OTP","tai_khoan",7L);
    }
    @Test void ownerSessionCurrentAddressAndLegacyStageAreChecked() {
        assertThrows(ApiException.class,()->service.verifyNew(7L,"another-session",id,"123456","ip"));
        row.put("old_email","other@test.invalid");
        assertThrows(ApiException.class,()->service.verifyNew(7L,session,id,"123456","ip"));
        row.put("old_email","old@test.invalid"); row.put("stage","CURRENT_OTP");
        assertThrows(ApiException.class,()->service.verifyNew(7L,session,id,"123456","ip"));
        assertThrows(ApiException.class,()->service.resend(7L,session,id,"ip"));
        verifyNoInteractions(encoder,jdbc);
    }
    @Test void cooldownCannotBeBypassedByRestartingOrChangingRecipient() {
        when(db.rows("select last_sent_at from email_change_challenge where tai_khoan_id=? order by last_sent_at desc limit 1",7L)).thenReturn(List.of(row));
        assertThrows(ApiException.class,()->service.requestNew(7L,session,null,"another@test.invalid","ip"));
        assertThrows(ApiException.class,()->service.resend(7L,session,id,"ip"));
        row.put("last_sent_at",Timestamp.from(now.minusSeconds(61)));
        service.resend(7L,session,id,"ip");
        verify(jdbc).update(eq("update email_change_challenge set stage='NEW_OTP',new_email=?,otp_hash=?,expires_at=?,attempts=0,last_sent_at=?,delivery_failed=false where id=?"),eq("new@test.invalid"),eq("new-hashed-code"),any(Timestamp.class),any(Timestamp.class),eq(id));
        verify(mail).sendEmailChange(eq("new@test.invalid"),matches("[0-9]{6}"),eq(true));
    }
    @Test void currentOtpIsConsumedBeforeIssuingVerificationGrant() {
        row.put("stage","CURRENT_OTP"); row.remove("verified_until");
        when(encoder.matches("123456","hashed-code")).thenReturn(true);
        service.verifyCurrent(7L,session,id,"123456","ip");
        verify(jdbc).update("update email_change_challenge set stage='CURRENT_VERIFIED',otp_hash=null,verified_until=? where id=?",Timestamp.from(now.plusSeconds(600)),id);
    }
    @Test void newEmailCannotBeRequestedOrConfirmedWithoutCurrentEmailVerification() {
        row.remove("verified_until");
        assertThrows(ApiException.class,()->service.requestNew(7L,session,null,"new@test.invalid","ip"));
        assertThrows(ApiException.class,()->service.requestNew(7L,session,id,"new@test.invalid","ip"));
        assertThrows(ApiException.class,()->service.verifyNew(7L,session,id,"123456","ip"));
        verifyNoInteractions(jdbc,encoder);
    }
    @Test void expiredCurrentEmailVerificationRequiresRestart() {
        row.put("verified_until",Timestamp.from(now));
        assertThrows(ApiException.class,()->service.requestNew(7L,session,id,"new@test.invalid","ip"));
        assertThrows(ApiException.class,()->service.verifyNew(7L,session,id,"123456","ip"));
        verifyNoInteractions(jdbc,encoder);
    }
    @Test void lateDeliveryFailureCannotInvalidateReplacementCode() {
        doThrow(new IllegalStateException()).when(mail).sendEmailChange(anyString(),anyString(),anyBoolean());
        service.requestCurrent(7L,session,"ip");
        verify(jdbc).update(eq("update email_change_challenge set delivery_failed=true,otp_hash=null where id=? and otp_hash=?"),any(UUID.class),eq("new-hashed-code"));
    }
}
