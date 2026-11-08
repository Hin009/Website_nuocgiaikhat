package vn.drinkstore.auth;

import java.time.*;
import java.util.*;
import org.springframework.stereotype.Component;
import org.springframework.http.HttpStatus;
import vn.drinkstore.common.ApiException;
import vn.drinkstore.security.Tokens;

@Component
public class PasswordResetRateLimit {
    private final Map<String,ArrayDeque<Instant>> requests=new HashMap<>();
    private final Clock clock;
    public PasswordResetRateLimit() { this(Clock.systemUTC()); }
    PasswordResetRateLimit(Clock clock) { this.clock=clock; }
    synchronized void check(String key,int limit,Duration window) {
        Instant now=clock.instant();
        clean(now);
        available(key,limit,window,now).addLast(now);
    }
    private void clean(Instant now) {
        requests.entrySet().removeIf(entry->entry.getValue().isEmpty() || entry.getValue().getLast().isBefore(now.minus(Duration.ofHours(1))));
    }
    private ArrayDeque<Instant> available(String key,int limit,Duration window,Instant now) {
        if(requests.size()>=4096 && !requests.containsKey(key)) throw limited();
        var times=requests.computeIfAbsent(key,ignored->new ArrayDeque<>());
        while(!times.isEmpty() && !times.getFirst().isAfter(now.minus(window))) times.removeFirst();
        if(times.size()>=limit) {
            long seconds=Math.max(1,(Duration.between(now,times.getFirst().plus(window)).toMillis()+999)/1000);
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS,"Đã đạt giới hạn gửi/xác minh OTP. Vui lòng thử lại sau "+seconds+" giây.");
        }
        return times;
    }
    public synchronized void request(String ip,String email) {
        Instant now=clock.instant();
        clean(now);
        String hash=Tokens.hash(email.trim().toLowerCase(Locale.ROOT));
        // Reserve all three limits together. A rejected retry must not spend another email/IP allowance.
        var cooldown=available("cooldown:"+hash,1,Duration.ofSeconds(60),now);
        var byEmail=available("email:"+hash,5,Duration.ofHours(1),now);
        var byIp=available("request-ip:"+Tokens.hash(ip),30,Duration.ofMinutes(15),now);
        cooldown.addLast(now); byEmail.addLast(now); byIp.addLast(now);
    }
    public void verify(String ip) { check("verify:"+Tokens.hash(ip),40,Duration.ofMinutes(15)); }
    public void complete(String ip) { check("complete:"+Tokens.hash(ip),20,Duration.ofMinutes(15)); }
    private ApiException limited() { return new ApiException(HttpStatus.TOO_MANY_REQUESTS,"Bạn thao tác quá nhiều lần. Vui lòng thử lại sau."); }
}
