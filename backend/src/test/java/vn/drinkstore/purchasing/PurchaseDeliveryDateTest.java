package vn.drinkstore.purchasing;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import jakarta.validation.Validation;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class PurchaseDeliveryDateTest {
    @Test void acceptsTodayAndFutureButRejectsPastDeliveryDates() {
        try(var factory=Validation.buildDefaultValidatorFactory()) {
            var validator=factory.getValidator();
            var line=new PurchaseController.Line(1,1,new BigDecimal("10000"));
            for(LocalDate date:List.of(LocalDate.now(),LocalDate.now().plusDays(7)))
                assertTrue(validator.validate(new PurchaseController.Create(1,date,List.of(line))).isEmpty());
            var violations=validator.validate(new PurchaseController.Create(1,LocalDate.now().minusDays(1),List.of(line)));
            assertTrue(violations.stream().anyMatch(v->v.getPropertyPath().toString().equals("expectedDate")));
            // Older clients and existing undated orders remain compatible.
            assertTrue(validator.validate(new PurchaseController.Create(1,null,List.of(line))).isEmpty());
        }
    }
}
