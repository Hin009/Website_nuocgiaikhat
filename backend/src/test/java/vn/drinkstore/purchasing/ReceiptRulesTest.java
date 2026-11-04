package vn.drinkstore.purchasing;

import java.math.BigDecimal;
import org.junit.jupiter.api.Test;
import vn.drinkstore.common.ApiException;
import static org.junit.jupiter.api.Assertions.*;

class ReceiptRulesTest {
    @Test void validatesProductDatesAndRequiresExpiredGoodsToBeRejected() {
        var today=java.time.LocalDate.now(java.time.ZoneId.of("Asia/Ho_Chi_Minh"));
        assertDoesNotThrow(()->ReceiptRules.validateDates(today.minusDays(10),today.plusDays(10),3));
        assertThrows(ApiException.class,()->ReceiptRules.validateDates(today.plusDays(1),today.plusDays(10),3));
        assertThrows(ApiException.class,()->ReceiptRules.validateDates(today,today.minusDays(1),3));
        assertThrows(ApiException.class,()->ReceiptRules.validateDates(today.minusDays(10),today.minusDays(1),3));
        assertDoesNotThrow(()->ReceiptRules.validateDates(today.minusDays(10),today.minusDays(1),0));
        assertThrows(ApiException.class,()->ReceiptRules.validateDates(today,null,3));
    }
    @Test void allowsEntirelyRejectedDeliveryButRequiresReason() {
        assertDoesNotThrow(()->ReceiptRules.validate(new PurchaseController.ReceiptLine(1,0,new BigDecimal("10000"),10,"Broken packaging")));
        assertThrows(ApiException.class,()->ReceiptRules.validate(new PurchaseController.ReceiptLine(1,0,new BigDecimal("10000"),10," ")));
    }
    @Test void rejectsEmptyAndNegativeDeliveries() {
        assertThrows(ApiException.class,()->ReceiptRules.validate(new PurchaseController.ReceiptLine(1,0,BigDecimal.ZERO)));
        assertThrows(ApiException.class,()->ReceiptRules.validate(new PurchaseController.ReceiptLine(1,-1,BigDecimal.ZERO,1,"Broken")));
        assertDoesNotThrow(()->ReceiptRules.validate(new PurchaseController.ReceiptLine(1,98,new BigDecimal("10000"),2,"Broken")));
    }

}
