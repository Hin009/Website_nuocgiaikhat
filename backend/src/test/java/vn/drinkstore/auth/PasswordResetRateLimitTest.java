package vn.drinkstore.auth;

import org.junit.jupiter.api.Test;
import java.time.*;
import vn.drinkstore.common.ApiException;
import static org.junit.jupiter.api.Assertions.*;

class PasswordResetRateLimitTest {
    static class MutableClock extends Clock {
        Instant now=Instant.parse("2026-11-08T06:00:00Z");
        public ZoneId getZone() { return ZoneOffset.UTC; }
        public Clock withZone(ZoneId zone) { return this; }
        public Instant instant() { return now; }
    }
    @Test void rejectedRapidRetriesDoNotConsumeHourlyOrIpAllowance() {
        var clock=new MutableClock();
        var limiter=new PasswordResetRateLimit(clock);
        limiter.request("127.0.0.1","customer@test.invalid");
        for(int i=0;i<40;i++) {
            var failure=assertThrows(ApiException.class,()->limiter.request("127.0.0.1","customer@test.invalid"));
            assertTrue(failure.getMessage().contains("60 giây"));
        }
        for(int i=0;i<4;i++) {
            clock.now=clock.now.plusSeconds(60);
            assertDoesNotThrow(()->limiter.request("127.0.0.1","customer@test.invalid"));
        }
        clock.now=clock.now.plusSeconds(60);
        assertThrows(ApiException.class,()->limiter.request("127.0.0.1","customer@test.invalid"));
        assertDoesNotThrow(()->limiter.request("127.0.0.1","another@test.invalid"));
        clock.now=clock.now.plusSeconds(3600);
        assertDoesNotThrow(()->limiter.request("127.0.0.1","customer@test.invalid"));
    }
    @Test void cooldownNormalizesEmailAndAppliesAcrossDifferentIps() {
        var limiter=new PasswordResetRateLimit();
        limiter.request("127.0.0.1"," Customer@Test.invalid ");
        assertThrows(ApiException.class,()->limiter.request("127.0.0.2","customer@test.invalid"));
        assertDoesNotThrow(()->limiter.request("127.0.0.2","another@test.invalid"));
    }
    @Test void verificationHasIndependentIpLimit() {
        var limiter=new PasswordResetRateLimit();
        for(int i=0;i<40;i++) limiter.verify("127.0.0.1");
        assertThrows(ApiException.class,()->limiter.verify("127.0.0.1"));
        assertDoesNotThrow(()->limiter.verify("127.0.0.2"));
    }
}
