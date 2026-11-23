package vn.drinkstore.billing;

import java.util.concurrent.ConcurrentHashMap;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;
import vn.drinkstore.common.Db;

/** Reads committed, durable notifications; reconnecting clients replay from their last id. */
@Component
@org.springframework.context.annotation.DependsOn("checkoutSchema")
public class PaymentEvents {
    @Configuration @EnableScheduling static class Scheduling {}
    private final Db db;
    private final ConcurrentHashMap<SseEmitter,Long> clients=new ConcurrentHashMap<>();
    public PaymentEvents(Db db) { this.db=db; }
    public SseEmitter subscribe(long after) {
        var emitter=new SseEmitter(60000L);
        emitter.onCompletion(()->clients.remove(emitter));
        emitter.onTimeout(()->{ clients.remove(emitter); emitter.complete(); });
        emitter.onError(e->clients.remove(emitter));
        clients.put(emitter,Math.max(0,after));
        return emitter;
    }
    @Scheduled(fixedDelay=2000) public void publish() {
        clients.forEach((emitter,after)->{
            try {
                for(var row:db.rows("select id,order_id,message,created_at from payment_notification where id>? order by id limit 100",after)) {
                    emitter.send(SseEmitter.event().name("payment").id(row.get("id").toString()).data(row));
                    clients.put(emitter,Db.n(row,"id"));
                }
                emitter.send(SseEmitter.event().comment("keepalive"));
            } catch(Exception e) { clients.remove(emitter); emitter.complete(); }
        });
    }
}
